#! /bin/bash
set -x
export AWS_MAX_ATTEMPTS=3

OUTPUT="/etc/ben/output"
PAIRED=""
UNPAIRED_F=""
UNPAIRED_R=""
while getopts "i:p:r:123" opt; do
    case $opt in
        i) PROJECTID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        r) RUNID="$OPTARG"
        ;;
        1) PAIRED="TRUE"
        ;;
        2) UNPAIRED_F="TRUE"
        ;;
        3) UNPAIRED_R="TRUE"
        ;;
    esac
done

source /vars/crux_vars.sh # gets $RUNID and $IPADDRESS

# source /vars/crux_vars.sh # get tronko db $RUNID
mkdir $PROJECTID-$PRIMER $PROJECTID-$PRIMER-rc


removeProcessedFiles() {
    PROJECTID=$1
    PRIMER=$2
    tronko_type=$3
    fr=$4


    if [[ "$tronko_type" == "paired_"* ]]; then
        checksums_file="$PROJECTID-$PRIMER/old/checksums_${fr}.txt"
    else
        checksums_file="$PROJECTID-$PRIMER/old/checksums.txt"
    fi
    # Only keep files that haven't been ran through assign
    # check if it's been run before
    if [ -e $checksums_file ]; then

        declare -A checksums
        # Read checksums from the file into the associative array
        while read -r checksum filename; do
            echo $filename
            echo $checksum
            checksums["$filename"]=$checksum
        done < "$checksums_file"

        # Check if any files in md5sum file were deleted
        # Create a temporary file
        temp_file=$(mktemp)
        ASV="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-$tronko_type.asv"
        FASTA="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-$tronko_type.fasta"
        if [[ "$tronko_type" == "paired_"* ]]; then
            TRONKO="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired.txt"
        else
            TRONKO="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-$tronko_type.txt"
        fi

        file_names=$(head -n 1 $ASV)
        IFS=$'\t' read -ra file_list <<< "$file_names"
        # Remove the first 2 cols from list
        file_list=("${file_list[@]:2}")

        for file in "${file_list[@]}"; do
            file="${file%$'\r'}"  # remove trail characters
            # Check if the file exists
            file_path="$PROJECTID-$PRIMER/paired/${file}_${fr}_filt.fastq.gz"
            if [ -f "$file_path" ]; then
                new_md5sum=$(md5sum $file_path | cut -d' ' -f1)
                if [ "${checksums["$file_path"]}" = "$new_md5sum" ]; then
                    # file exists, and the MD5 checksums are the same, rm QC file
                    echo "MD5 checksums are the same. Deleting local QC file..."
                    md5sum "$file_path" >> "$temp_file"
                    rm $file_path
                else
                    echo "MD5 checksums are different. Keeping file '$file_path'"
                    echo "Deleting old data from '$file_path'"
                    # add new checksum
                    md5sum "$file_path" >> "$temp_file"
                    # remove $file column from asv
                    awk -F'\t' -v colname="$file" 'BEGIN {OFS = "\t"} {
                        if (NR == 1) {
                            for (i = 1; i <= NF; i++) {
                                if ($i == colname) {
                                    delete $i
                                }
                            }
                            print
                        } else {
                            for (i = 1; i <= NF; i++) {
                                if ($i == colname) {
                                    delete $i
                                }
                            }
                            print
                        }
                    }' "$ASV" > "$ASV.new"
                    mv $ASV.new $ASV
                fi
            else
                # If previously run file no longer exists in samples, or checksum is different, delete it from assign output files
                echo "File '$file_path' no longer exists in QC/$PRIMER/paired. Deleting $PRIMER assign data for '$file_path' ..."
                # remove $file column from asv
                awk -F'\t' -v colname="$file" 'BEGIN {OFS = "\t"} {
                    if (NR == 1) {
                        for (i = 1; i <= NF; i++) {
                            if ($i == colname) {
                                delete $i
                            }
                        }
                        print
                    } else {
                        for (i = 1; i <= NF; i++) {
                            if ($i == colname) {
                                delete $i
                            }
                        }
                        print
                    }
                }' "$ASV" > "$ASV.new"
                mv $ASV.new $ASV


            fi
        done
        mv $temp_file $checksums_file

        # loop $ASV for rows with only 0's. Del those rows and append to id.txt
        removed_id=$(mktemp)
        awk -F'\t' '{
            # Check if all fields except the first two are zero
            delete_zero_row = 1
            for (i = 3; i <= NF; i++) {
                if ($i != 0) {
                    delete_zero_row = 0
                    break
                }
            }
            
            if (delete_zero_row == 0) {
                print >> "'$ASV.new'"
            } else {
                print $1 >> "'$removed_id'"
            }
        }' "$ASV"
        mv $ASV.new $ASV

        # loop through $removed_id file and delete entries from fasta and tronko output
        while read -r id; do
            # Remove the ID and its sequence from the fasta file
            sed -i "/^>$id$/ {N;N;N;d;}" "$fasta_file"
            # Remove the ID row in tronko output
            sed -i "/$id/d" $TRONKO
        done < "$removed_id"

        rm $removed_id
    else
        echo "MD5 file does not exist. Keeping all files."
        # create md5 checksum
        if [[ "$tronko_type" == "paired_"* ]]; then
            for file in "$PROJECTID-$PRIMER/paired"/*_${fr}_filt.fastq.gz; do
                md5sum "$file" >> "$checksums_file"
            done
        else
            for file in "$PROJECTID-$PRIMER/${tronko_type}/"*; do
                md5sum "$file" >> $checksums_file
            done
        fi
    fi
}

if [ "${PAIRED}" = "TRUE" ]
then
    # download tronko database
    aws s3 sync s3://$BUCKET/CruxV2/$RUNID/$PRIMER/tronko/ $PROJECTID-$PRIMER/tronkodb/ --exclude "*" --include "$PRIMER*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp s3://$BUCKET/CruxV2/$RUNID/$PRIMER/tronko/reference_tree.txt.gz $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # download checksum
    aws s3 sync s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/paired $PROJECTID-$PRIMER/old --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


    # download QC sample paired files
    aws s3 sync s3://$BUCKET/projects/$PROJECTID/QC/$PRIMER/paired/ $PROJECTID-$PRIMER/paired/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    removeProcessedFiles "$PROJECTID" "$PRIMER" "paired_F" "F"

    # upload new checksum_F
    aws s3 cp $PROJECTID-$PRIMER/old/checksums_F.txt s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/paired/checksums_F.txt --endpoint-url https://js2.jetstream-cloud.org:8001/

    removeProcessedFiles "$PROJECTID" "$PRIMER" "paired_R" "R"

    # upload new checksum_R
    aws s3 cp $PROJECTID-$PRIMER/old/checksums_R.txt s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/paired/checksums_R.txt --endpoint-url https://js2.jetstream-cloud.org:8001/

    # create ASV files
    python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/paired --out $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.asv --primer $PRIMER --paired

    # run tronko assign paired v1
    time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -p -z -w -1 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta -2 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt

    # filter tronko output
    /mnt/chisquared_filter.pl $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.asv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.asv

    # Count rows with values less than 5 in the 4th and 5th columns in v1 of paired
    count_1=$(awk -F '\t' '($4 < 5) && ($5 < 5) { count++ } END { print count }' "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_filtered.txt")
    if [[ -z "$count_1" ]]; then
        count_1=0
    fi
    # create rc ASV files
    python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/paired --out $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.asv --primer $PRIMER --paired --rc

    # run tronko assign paired v2 (rc)
    time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -p -z -w -1 $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.fasta -2 $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired.txt

    # filter tronko output
    /mnt/chisquared_filter.pl $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired.txt $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.fasta $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.fasta $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.asv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.asv

    # Count rows with values less than 5 in the 4th and 5th columns in v2 (rc) of paired
    count_2=$(awk -F '\t' '($4 < 5) && ($5 < 5) { count++ } END { print count }' "$PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_filtered.txt")
    if [[ -z "$count_2" ]]; then
        count_2=0
    fi

    # Compare counts and upload folder with the highest count
    if [ "$count_1" -ge "$count_2" ]; then
        echo "v1 has the highest count: $count_1"
        # rename filtered files
        mv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_filtered.txt $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt
        mv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F_filtered.asv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.asv
        mv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R_filtered.asv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.asv
        mv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F_filtered.fasta $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta
        mv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R_filtered.fasta $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta

        # combine old and new files
        old_asv_f="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired_F.asv"
        old_asv_r="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired_R.asv"
        old_fasta_f="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired_F.fasta"
        old_fasta_r="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired_R.fasta"
        old_output="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired.txt"
        if [ -f "$old_asv_f" ]; then
            OFS="\t"
            awk 'NR==FNR{next} FNR==1{next} {for(i=3; i<=NF; i++) $i = $i OFS $i} 1' $old_asv_f $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.asv > merged_f.asv
            mv merged_f.asv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.asv

            awk 'BEGIN {OFS="\t"} NR==FNR{if (FNR==1) next; for(i=2; i<=NF; i++) header = header OFS $i; next} FNR==1 {print header} {print $1, $0}' "$old_asv_r" "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.asv" > merged_r.asv
            
            awk 'NR==FNR{next} FNR==1{next} {for(i=3; i<=NF; i++) $i = $i OFS $i} 1' $old_asv_r $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.asv > merged_r.asv
            mv merged_r.asv $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.asv

            tail -n +2 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta | cat >> $old_fasta_f
            mv $old_fasta_f $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta

            tail -n +2 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta | cat >> $old_fasta_r
            mv $old_fasta_r $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta

            tail -n +2 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt | cat >> $old_output
            mv $old_output $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt
        fi

        # upload output
        aws s3 sync $PROJECTID-$PRIMER/ s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/paired/ --exclude "*" --include "$PROJECTID-$PRIMER-paired*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    else
        echo "v2 (rc) has the highest count: $count_2"
        # rename filtered files
        # rename filtered files
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_filtered.txt $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired.txt
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F_filtered.asv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.asv
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R_filtered.asv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.asv
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F_filtered.fasta $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.fasta
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R_filtered.fasta $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.fasta

        # combine old and new files
        old_asv_f="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired_F.asv"
        old_asv_r="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired_R.asv"
        old_fasta_f="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired_F.fasta"
        old_fasta_r="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired_R.fasta"
        old_output="$PROJECTID-$PRIMER/old/$PROJECTID-$PRIMER-paired.txt"
        if [ -f "$old_asv_f" ]; then
            awk 'NR==FNR{next} FNR==1{next} {for(i=3; i<=NF; i++) $i = $i OFS $i} 1' $old_asv_f $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.asv > merged_f.asv
            mv merged_f.asv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.asv

            awk 'NR==FNR{next} FNR==1{next} {for(i=3; i<=NF; i++) $i = $i OFS $i} 1' $old_asv_r $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.asv > merged_r.asv
            mv merged_R.asv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.asv

            tail -n +2 $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.fasta | cat >> $old_fasta_f
            mv $old_fasta_f $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.fasta

            tail -n +2 $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.fasta | cat >> $old_fasta_r
            mv $old_fasta_r $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.fasta

            tail -n +2 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt | cat >> $old_output
            mv $old_output $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt
        fi

        # upload output
        aws s3 sync $PROJECTID-$PRIMER-rc/ s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/paired/ --exclude "*" --include "$PROJECTID-$PRIMER-paired*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    fi

    # cleanup
    # rm -r $PROJECTID-$PRIMER/* $PROJECTID-$PRIMER-rc/*
fi

# if [ "${UNPAIRED_F}" = "TRUE" ]
# then
#     # check if tronko assign already ran on unpaired_f
#     # dir_exists=$(aws s3 ls s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/unpaired_F/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
#     # if [ "$dir_exists" -gt 0 ]; then
#     #     # tronko assign unpaired_f file exists on js2
#     #     echo "Skipping tronko assign unpaired_f for: $PROJECTID-$PRIMER"
#     # else
#     # tronko assign unpaired_f does not exist on js2, run
#     echo "File does not exist on s3 - run unpaired_f: $PROJECTID-$PRIMER"
#     # download tronko database
#     aws s3 sync s3://$BUCKET/CruxV2/$RUNID/$PRIMER/tronko/ $PROJECTID-$PRIMER/tronkodb/ --exclude "*" --include "$PRIMER*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
#     aws s3 cp s3://$BUCKET/CruxV2/$RUNID/$PRIMER/tronko/reference_tree.txt.gz $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
#     # download QC sample unpaired_F files
#     aws s3 sync s3://$BUCKET/projects/$PROJECTID/QC/$PRIMER/unpaired_F/ $PROJECTID-$PRIMER/unpaired_F/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

#     # create ASV files
#     python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/unpaired_F/ --out $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.asv --primer $PRIMER --unpairedf

#     # run tronko assign
#     time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.txt

#     # Count rows with values less than 5 in the 4th column in v1 of unpaired_F
#     count_1=$(awk -F '\t' '$4 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.txt")
#     if [[ -z "$count_1" ]]; then
#         count_1=0
#     fi
#     # run tronko assign unpaired_F v2 (rc)
#     time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.fasta -6 -C 1 -c 5 -v -o $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_F.txt

#     # Count rows with values less than 5 in the 4th column in v2 (rc) of unpaired_F
#     count_2=$(awk -F '\t' '$4 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_F.txt")
#     if [[ -z "$count_2" ]]; then
#         count_2=0
#     fi
#     # Compare counts and upload folder with the highest count
#     if [ "$count_1" -ge "$count_2" ]; then
#         echo "v1 has the highest count: $count_1"
#         # split assign output
#         aws s3 sync $PROJECTID-$PRIMER/ s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/unpaired_F --exclude "*" --include "$PROJECTID-$PRIMER-unpaired_F*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
#     else
#         echo "v2 (rc) has the highest count: $count_2"
#         # split assign output
#         aws s3 sync $PROJECTID-$PRIMER/ s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/unpaired_F --exclude "*" --include "$PROJECTID-$PRIMER-unpaired_F*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
#         aws s3 cp $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_F.txt s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/unpaired_F/$PROJECTID-$PRIMER-unpaired_F.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
#     fi

#     # cleanup
#     rm -r $PROJECTID-$PRIMER/* $PROJECTID-$PRIMER-rc/*
#     # fi
# fi

# if [ "${UNPAIRED_R}" = "TRUE" ]
# then
#     # # check if tronko assign already ran on unpaired_r files
#     # dir_exists=$(aws s3 ls s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/unpaired_R/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
#     # if [ "$dir_exists" -gt 0 ]; then
#     #     # tronko assign unpaired_r file exists on js2
#     #     echo "Skipping tronko assign unpaired_r for: $PROJECTID-$PRIMER"
#     # else
#     # tronko assign unpaired_r does not exist on js2, run
#     echo "File does not exist on s3 - run unpaired_r: $PROJECTID-$PRIMER"
#     # download tronko database
#     aws s3 sync s3://$BUCKET/CruxV2/$RUNID/$PRIMER/tronko/ $PROJECTID-$PRIMER/tronkodb/ --exclude "*" --include "$PRIMER*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
#     aws s3 cp s3://$BUCKET/CruxV2/$RUNID/$PRIMER/tronko/reference_tree.txt.gz $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
#     # download QC sample unpaired_R
#     aws s3 sync s3://$BUCKET/projects/$PROJECTID/QC/$PRIMER/unpaired_R/ $PROJECTID-$PRIMER/unpaired_R/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

#     # create ASV files
#     python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/unpaired_R --out $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.asv --primer $PRIMER --unpairedr

#     # run tronko assign
#     time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.fasta -6 -C 1 -c 5 -v -o $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.txt

#     # Count rows with values less than 5 in the 5th column in v1 of unpaired_R
#     count_1=$(awk -F '\t' '$5 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.txt")
#     if [[ -z "$count_1" ]]; then
#         count_1=0
#     fi
#     # run tronko assign unpaired_R v2 (rc)
#     time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_R.txt

#     # Count rows with values less than 5 in the 5th column in v2 (rc) of unpaired_R
#     count_2=$(awk -F '\t' '$5 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_R.txt")
#     if [[ -z "$count_2" ]]; then
#         count_2=0
#     fi
#     # Compare counts and upload folder with the highest count
#     if [ "$count_1" -gt "$count_2" ]; then
#         echo "v1 has the highest count: $count_1"
#         # split assign output
#         aws s3 sync $PROJECTID-$PRIMER/ s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/unpaired_R --exclude "*" --include "$PROJECTID-$PRIMER-unpaired_R*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
#     else
#         echo "v2 (rc) has the highest count: $count_2"
#         # split assign output
#         aws s3 sync $PROJECTID-$PRIMER/ s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/unpaired_R --exclude "*" --include "$PROJECTID-$PRIMER-unpaired_R*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
#         aws s3 cp $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_R.txt s3://$BUCKET/projects/$PROJECTID/assign/$PRIMER/unpaired_R/$PROJECTID-$PRIMER-unpaired_R.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
#     fi

#     # cleanup
#     rm -r $PROJECTID-$PRIMER/* $PROJECTID-$PRIMER-rc/*
#     # fi
# fi

# mkdir ${PROJECTID}_processed_tronko
# # dl all assign folders for $PROJECTID
# aws s3 sync s3://$BUCKET/projects/$PROJECTID/assign ./$PROJECTID --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
# # run process_tronko.py for each primer with 1, 5, 10, 30, 50, and 100 mismatches
# mismatches=(1 5 10 25 50 100)
# for dir in "$PROJECTID"/*; do
#   if [ -d "$dir" ]; then
#     primer=$(basename $dir)
#     mkdir ${PROJECTID}_processed_tronko/$primer
#     for mismatch in "${mismatches[@]}"; do
#         python3 /mnt/process_tronko.py --base_dir $dir --out ${PROJECTID}_processed_tronko/$primer/q30_${primer}_Max${mismatch}.txt --mismatches $mismatch --project $PROJECTID
#     done
#   fi
# done
# # zip
# tar -czvf ${PROJECTID}_processed_tronko.tar.gz ${PROJECTID}_processed_tronko
# # upload
# aws s3 cp ${PROJECTID}_processed_tronko.tar.gz s3://$BUCKET/projects/$PROJECTID/${PROJECTID}_processed_tronko.tar.gz --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


# # download primer list for jwt step. Downloading here since we rewrite aws creds in next line.
# aws s3 cp s3://$BUCKET/projects/$PROJECTID/QC/metabarcode_loci_min_merge_length.txt /mnt/jwt/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# # update s3 bucket creds
# # should be temporary until s3 bucket is the same for all steps
# export AWS_ACCESS_KEY_ID=$AWS_S3_ACCESS_KEY_ID
# export AWS_SECRET_ACCESS_KEY=$AWS_S3_SECRET_ACCESS_KEY
# export AWS_DEFAULT_REGION=$AWS_S3_DEFAULT_REGION
# export AWS_BUCKET=$AWS_S3_BUCKET

# # upload to aws s3 bucket
# aws s3 cp ${PROJECTID}_processed_tronko.tar.gz s3://$AWS_BUCKET/projects/$PROJECTID/${PROJECTID}_processed_tronko.tar.gz --no-progress


# # call processing_notif.sh
# cd /mnt/jwt
# ./processing_notif.sh -i $PROJECTID

# # cleanup
# rm -r ${PROJECTID}*

# # download 
# # # Trigger taxonomy initializer script
# curl -X POST http://$IPADDRESS:8004/initializer \
#      -H "Content-Type: application/json" \
#      -d "{
#            \"ProjectID\": \"$PROJECTID\"
#          }"



# paired:
# run both versions 
# v2: switch -1 and -2 files
# then, pick the output file with the most lines with mismatches under 5

# in upaired_F run both versions, v2:run with -v
# then, pick the output file with the most lines with mismatches under 5

# unpaired_R run both versions:
# v2: run without -v