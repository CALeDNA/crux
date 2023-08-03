#! /bin/bash
set -x

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

# source /vars/crux_vars.sh # get tronko db $RUNID
mkdir $PROJECTID-$PRIMER $PROJECTID-$PRIMER-rc

if [ "${PAIRED}" = "TRUE" ]
then
    count_1=0
    count_2=0
    # check if tronko assign already ran on paired
    dir_exists=$(aws s3 ls s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
    if [ "$dir_exists" -gt 0 ]; then
        # tronko assign paired file exists on js2
        echo "Skipping tronko assign paired for: $PROJECTID-$PRIMER"
    else
        # tronko assign paired does not exist on js2, run
        echo "File does not exist on s3 - running paired on $PRIMER"
        # download tronko database
        aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$PRIMER/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        
        # download QC sample paired files
        aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired/ $PROJECTID-$PRIMER/paired/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

        # create ASV files
        python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/paired --out $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.asv --primer $PRIMER --paired

        # run tronko assign paired v1
        time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -p -z -w -1 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta -2 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt

        # filter tronko output
        ./chisquared_filter.pl $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired.txt $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta >> $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_filtered.txt

        # Count rows with values less than 5 in the 4th and 5th columns in v1 of paired
        count_1=$((count_1 + $(awk -F '\t' '($4 < 5) && ($5 < 5) { count++ } END { print count }' "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_filtered.txt")))

        # run tronko assign paired v2 (rc)
        time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -p -z -w -2 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta -1 $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired.txt

        # filter tronko output
        ./chisquared_filter.pl $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired.txt $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_R.fasta $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-paired_F.fasta >> $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_filtered.txt

        # Count rows with values less than 5 in the 4th and 5th columns in v2 (rc) of paired
        count_2=$((count_2 + $(awk -F '\t' '($4 < 5) && ($5 < 5) { count++ } END { print count }' "$PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_filtered.txt")))

        # Compare counts and upload folder with the highest count
        if [ "$count_1" -gt "$count_2" ]; then
            echo "v1 has the highest count: $count_1"
            # split assign output
            aws s3 sync $PROJECTID-$PRIMER/ s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/ --exclude "*" --include "$PROJECTID-$PRIMER-paired*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        else
            echo "v2 (rc) has the highest count: $count_2"
            # split assign output
            aws s3 sync $PROJECTID-$PRIMER/ s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/ --exclude "*" --include "$PROJECTID-$PRIMER-paired*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
            aws s3 cp $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/$PROJECTID-$PRIMER-paired.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
            aws s3 cp $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-paired_filtered.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/$PROJECTID-$PRIMER-paired_filtered.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        fi

        # cleanup
        rm -r $PROJECTID-$PRIMER/* $PROJECTID-$PRIMER-rc/*
    fi
fi

if [ "${UNPAIRED_F}" = "TRUE" ]
then
    count_1=0
    count_2=0
    # check if tronko assign already ran on unpaired_f
    dir_exists=$(aws s3 ls s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
    if [ "$dir_exists" -gt 0 ]; then
        # tronko assign unpaired_f file exists on js2
        echo "Skipping tronko assign unpaired_f for: $PROJECTID-$PRIMER"
    else
        # tronko assign unpaired_f does not exist on js2, run
        echo "File does not exist on s3 - run unpaired_f: $PROJECTID-$PRIMER"
        # download tronko database
        aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$PRIMER/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        
        # download QC sample unpaired_F files
        aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F/ $PROJECTID-$PRIMER/unpaired_F/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

        # create ASV files
        python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/unpaired_F/ --out $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.asv --primer $PRIMER --unpairedf

        # run tronko assign
        time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.txt

        # Count rows with values less than 5 in the 4th column in v1 of unpaired_F
        count_1=$((count_1 + $(awk -F '\t' '$4 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.txt")))

        # run tronko assign unpaired_F v2 (rc)
        time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_F.fasta -6 -C 1 -c 5 -v -o $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_F.txt

        # Count rows with values less than 5 in the 4th column in v2 (rc) of unpaired_F
        count_2=$((count_2 + $(awk -F '\t' '$4 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_F.txt")))

        # Compare counts and upload folder with the highest count
        if [ "$count_1" -gt "$count_2" ]; then
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
    fi
fi

if [ "${UNPAIRED_R}" = "TRUE" ]
then
    count_1=0
    count_2=0
    # check if tronko assign already ran on unpaired_r files
    dir_exists=$(aws s3 ls s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
    if [ "$dir_exists" -gt 0 ]; then
        # tronko assign unpaired_r file exists on js2
        echo "Skipping tronko assign unpaired_r for: $PROJECTID-$PRIMER"
    else
        # tronko assign unpaired_r does not exist on js2, run
        echo "File does not exist on s3 - run unpaired_r: $PROJECTID-$PRIMER"
        # download tronko database
        aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$PRIMER/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        
        # download QC sample unpaired_R
        aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R/ $PROJECTID-$PRIMER/unpaired_R/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

        # create ASV files
        python3 /mnt/asv.py --dir $PROJECTID-$PRIMER/unpaired_R --out $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.asv --primer $PRIMER --unpairedr

        # run tronko assign
        time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.fasta -6 -C 1 -c 5 -v -o $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.txt

        # Count rows with values less than 5 in the 5th column in v1 of unpaired_R
        count_1=$((count_1 + $(awk -F '\t' '$5 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.txt")))

        # run tronko assign unpaired_R v2 (rc)
        time tronko-assign -r -f $PROJECTID-$PRIMER/tronkodb/reference_tree.txt.gz -a $PROJECTID-$PRIMER/tronkodb/$PRIMER.fasta -s -w -g $PROJECTID-$PRIMER/$PROJECTID-$PRIMER-unpaired_R.fasta -6 -C 1 -c 5 -o $PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_R.txt

        # Count rows with values less than 5 in the 5th column in v2 (rc) of unpaired_R
        count_2=$((count_2 + $(awk -F '\t' '$5 < 5 { count++ } END { print count }' "$PROJECTID-$PRIMER-rc/$PROJECTID-$PRIMER-unpaired_R.txt")))

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
    fi
fi



# paired:
# run both versions 
# v2: switch -1 and -2 files
# then, pick the output file with the most lines with mismatches under 5

# in upaired_F run both versions, v2:run with -v
# then, pick the output file with the most lines with mismatches under 5

# unpaired_R run both versions:
# v2: run without -v

# cleanup
rm -r $PROJECTID-$PRIMER $PROJECTID-$PRIMER-rc