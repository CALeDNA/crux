#! /bin/bash

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

if [ "${PAIRED}" = "TRUE" ]
then
    # check if tronko assign already ran on paired
    # dir_exists=$(aws s3 ls s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
    # if [ "$dir_exists" -gt 0 ]; then
    #     # tronko assign paired file exists on js2
    #     echo "Skipping tronko assign paired for: $PROJECTID-$PRIMER"
    # else
    # tronko assign paired does not exist on js2, run
    echo "File does not exist on s3 - running paired on $PRIMER"
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko/ $PROJECTID-$PRIMER/tronkodb/ --exclude "*" --include "$PRIMER*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko/reference_tree.txt.gz $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample paired files
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired/ $PROJECTID-$PRIMER/paired/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

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
        # upload output
        aws s3 sync $PROJECTID-$PRIMER/ s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/ --exclude "*" --include "$PROJECTID-$PRIMER-paired*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    else
        echo "v2 (rc) has the highest count: $count_2"
        # rename filtered files
        # rename filtered files
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_filtered.txt $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired.txt
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F_filtered.asv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.asv
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R_filtered.asv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.asv
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F_filtered.fasta $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_F.fasta
        mv $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R_filtered.fasta $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_R.fasta
        # upload output
        aws s3 sync $PROJECTID-$PRIMER-rc/ s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/ --exclude "*" --include "$PROJECTID-$PRIMER-paired*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    fi

    # cleanup
    rm -r $PROJECTID-$PRIMER/* $PROJECTID-$PRIMER-rc/*
fi

if [ "${UNPAIRED_F}" = "TRUE" ]
then
    # check if tronko assign already ran on unpaired_f
    # dir_exists=$(aws s3 ls s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
    # if [ "$dir_exists" -gt 0 ]; then
    #     # tronko assign unpaired_f file exists on js2
    #     echo "Skipping tronko assign unpaired_f for: $PROJECTID-$PRIMER"
    # else
    # tronko assign unpaired_f does not exist on js2, run
    echo "File does not exist on s3 - run unpaired_f: $PROJECTID-$PRIMER"
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko/ $PROJECTID-$PRIMER/tronkodb/ --exclude "*" --include "$PRIMER*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko/reference_tree.txt.gz $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample unpaired_F files
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F/ $PROJECTID-$PRIMER/unpaired_F/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # create ASV files
    python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/unpaired_F/ --out $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.asv --primer $PRIMER --unpairedf

    # run tronko assign
    time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.txt

    # Count rows with values less than 5 in the 4th column in v1 of unpaired_F
    count_1=$(awk -F '\t' '$4 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.txt")
    if [[ -z "$count_1" ]]; then
        count_1=0
    fi
    # run tronko assign unpaired_F v2 (rc)
    time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.fasta -6 -C 1 -c 5 -v -o $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_F.txt

    # Count rows with values less than 5 in the 4th column in v2 (rc) of unpaired_F
    count_2=$(awk -F '\t' '$4 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_F.txt")
    if [[ -z "$count_2" ]]; then
        count_2=0
    fi
    # Compare counts and upload folder with the highest count
    if [ "$count_1" -ge "$count_2" ]; then
        echo "v1 has the highest count: $count_1"
        # split assign output
        aws s3 sync $PROJECTID-$PRIMER/ s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F --exclude "*" --include "$PROJECTID-$PRIMER-unpaired_F*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    else
        echo "v2 (rc) has the highest count: $count_2"
        # split assign output
        aws s3 sync $PROJECTID-$PRIMER/ s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F --exclude "*" --include "$PROJECTID-$PRIMER-unpaired_F*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        aws s3 cp $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_F.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F/$PROJECTID-$PRIMER-unpaired_F.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    fi

    # cleanup
    rm -r $PROJECTID-$PRIMER/* $PROJECTID-$PRIMER-rc/*
    # fi
fi

if [ "${UNPAIRED_R}" = "TRUE" ]
then
    # # check if tronko assign already ran on unpaired_r files
    # dir_exists=$(aws s3 ls s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
    # if [ "$dir_exists" -gt 0 ]; then
    #     # tronko assign unpaired_r file exists on js2
    #     echo "Skipping tronko assign unpaired_r for: $PROJECTID-$PRIMER"
    # else
    # tronko assign unpaired_r does not exist on js2, run
    echo "File does not exist on s3 - run unpaired_r: $PROJECTID-$PRIMER"
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko/ $PROJECTID-$PRIMER/tronkodb/ --exclude "*" --include "$PRIMER*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko/reference_tree.txt.gz $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample unpaired_R
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R/ $PROJECTID-$PRIMER/unpaired_R/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # create ASV files
    python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/unpaired_R --out $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.asv --primer $PRIMER --unpairedr

    # run tronko assign
    time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.fasta -6 -C 1 -c 5 -v -o $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.txt

    # Count rows with values less than 5 in the 5th column in v1 of unpaired_R
    count_1=$(awk -F '\t' '$5 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.txt")
    if [[ -z "$count_1" ]]; then
        count_1=0
    fi
    # run tronko assign unpaired_R v2 (rc)
    time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_R.txt

    # Count rows with values less than 5 in the 5th column in v2 (rc) of unpaired_R
    count_2=$(awk -F '\t' '$5 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_R.txt")
    if [[ -z "$count_2" ]]; then
        count_2=0
    fi
    # Compare counts and upload folder with the highest count
    if [ "$count_1" -gt "$count_2" ]; then
        echo "v1 has the highest count: $count_1"
        # split assign output
        aws s3 sync $PROJECTID-$PRIMER/ s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R --exclude "*" --include "$PROJECTID-$PRIMER-unpaired_R*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    else
        echo "v2 (rc) has the highest count: $count_2"
        # split assign output
        aws s3 sync $PROJECTID-$PRIMER/ s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R --exclude "*" --include "$PROJECTID-$PRIMER-unpaired_R*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        aws s3 cp $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_R.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R/$PROJECTID-$PRIMER-unpaired_R.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    fi

    # cleanup
    rm -r $PROJECTID-$PRIMER/* $PROJECTID-$PRIMER-rc/*
    # fi
fi

mkdir ${PROJECTID}_processed_tronko
# dl all assign folders for $PROJECTID
aws s3 sync s3://ednaexplorer/projects/$PROJECTID/assign ./$PROJECTID --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
# run process_tronko.py for each primer with 1, 5, 10, 30, 50, and 100 mismatches
mismatches=(1 5 10 25 50 100)
for dir in "$PROJECTID"/*; do
  if [ -d "$dir" ]; then
    primer=$(basename $dir)
    mkdir ${PROJECTID}_processed_tronko/$primer
    for mismatch in "${mismatches[@]}"; do
        python3 /mnt/process_tronko.py --base_dir $dir --out ${PROJECTID}_processed_tronko/$primer/q30_${primer}_Max${mismatch}.txt --mismatches $mismatch --project $PROJECTID
    done
  fi
done
# zip
tar -czvf ${PROJECTID}_processed_tronko.tar.gz ${PROJECTID}_processed_tronko
# upload
aws s3 cp ${PROJECTID}_processed_tronko.tar.gz s3://ednaexplorer/projects/$PROJECTID/${PROJECTID}_processed_tronko.tar.gz --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


# download primer list for jwt step. Downloading here since we rewrite aws creds in next line.
aws s3 cp s3://ednaexplorer/projects/$PROJECTID/QC/metabarcode_loci_min_merge_length.txt /mnt/jwt/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# update s3 bucket creds
# should be temporary until s3 bucket is the same for all steps
export AWS_ACCESS_KEY_ID=$AWS_S3_ACCESS_KEY_ID
export AWS_SECRET_ACCESS_KEY=$AWS_S3_SECRET_ACCESS_KEY
export AWS_DEFAULT_REGION=$AWS_S3_DEFAULT_REGION
export AWS_BUCKET=$AWS_S3_BUCKET

# upload to aws s3 bucket
aws s3 cp ${PROJECTID}_processed_tronko.tar.gz s3://$AWS_BUCKET/projects/$PROJECTID/${PROJECTID}_processed_tronko.tar.gz --no-progress


# call processing_notif.sh
cd /mnt/jwt
./processing_notif.sh -i $PROJECTID

# cleanup
rm -r ${PROJECTID}*

# download 
# # Trigger taxonomy initializer script
curl -X POST http://$IPADDRESS:8004/initializer \
     -H "Content-Type: application/json" \
     -d "{
           \"ProjectID\": \"$PROJECTID\"
         }"



# paired:
# run both versions 
# v2: switch -1 and -2 files
# then, pick the output file with the most lines with mismatches under 5

# in upaired_F run both versions, v2:run with -v
# then, pick the output file with the most lines with mismatches under 5

# unpaired_R run both versions:
# v2: run without -v