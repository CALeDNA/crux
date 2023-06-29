#! /bin/bash
set -x

OUTPUT="/etc/ben/output"
PAIRED=""
UNPAIRED_F=""
UNPAIRED_R=""
while getopts "f:i:p:123" opt; do
    case $opt in
        f) FILE="$OPTARG"
        ;;
        i) PROJECTID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        1) PAIRED="TRUE"
        ;;
        2) UNPAIRED_F="TRUE"
        ;;
        3) UNPAIRED_R="TRUE"
        ;;
    esac
done

source /vars/crux_vars.sh # get tronko db $RUNID
mkdir $PROJECTID-$FILE $PROJECTID-$FILE-rc

if [ "${PAIRED}" = "TRUE" ]
then
    # check if tronko assign already ran on paired
    not_exists=$(aws s3api head-object --bucket ednaexplorer --key projects/$PROJECTID/assign/$PRIMER/paired/$FILE.txt --endpoint-url https://js2.jetstream-cloud.org:8001/ >/dev/null 2>1; echo $?)
    if [ "$((not_exists))" -ne 255 ]; then
        # tronko assign paired file exists on js2
        echo "Skipping tronko assign paired for: $FILE"
    else
        # tronko assign paired does not exist on js2, run
        echo "run paired: $FILE"
        # download tronko database
        aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        
        # download QC sample paired files
        aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

        # run tronko assign paired v1
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -p -z -w -q -1 $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -2 $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt

        # Count rows with values less than 5 in the 4th and 5th columns in v1 of paired
        count_1=0
        for file in $PROJECTID-$FILE/*.txt; do
            count_1=$((count_1 + $(awk -F '\t' '($4 < 5) && ($5 < 5) { count++ } END { print count }' "$file")))
        done

        # run tronko assign paired v2 (rc)
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -p -z -w -q -2 $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -1 $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE-rc/$FILE.txt

        # Count rows with values less than 5 in the 4th and 5th columns in v2 (rc) of paired
        count_2=0
        for file in "$PROJECTID-$FILE-rc"/*.txt; do
            count_2=$((count_2 + $(awk -F '\t' '($4 < 5) && ($5 < 5) { count++ } END { print count }' "$file")))
        done

        # Compare counts and upload folder with the highest count
        if [ "$count_1" -gt "$count_2" ]; then
            echo "v1 has the highest count: $count_1"
            # upload to aws
            aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        else
            echo "v2 (rc) has the highest count: $count_2"
            # upload to aws
            aws s3 cp $PROJECTID-$FILE-rc/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        fi

        # cleanup
        rm -r $PROJECTID-$FILE/* $PROJECTID-$FILE-rc/*
    fi
fi

if [ "${UNPAIRED_F}" = "TRUE" ]
then
    # check if tronko assign already ran on unpaired_f
    not_exists=$(aws s3api head-object --bucket ednaexplorer --key projects/$PROJECTID/assign/$PRIMER/unpaired_F/$FILE.txt --endpoint-url https://js2.jetstream-cloud.org:8001/ >/dev/null 2>1; echo $?)
    if [ "$((not_exists))" -ne 255 ]; then
        # tronko assign unpaired_f file exists on js2
        echo "Skipping tronko assign unpaired_f for: $FILE"
    else
        # tronko assign unpaired_f does not exist on js2, run
        echo "run unpaired_f: $FILE"
        # download tronko database
        aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        
        # download QC sample unpaired_F
        aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

        # run tronko assign
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt

        # Count rows with values less than 5 in the 4th column in v1 of unpaired_F
        count_1=0
        for file in $PROJECTID-$FILE/*.txt; do
            count_1=$((count_1 + $(awk -F '\t' '$4 < 5 { count++ } END { print count }' "$file")))
        done

        # run tronko assign unpaired_F v2 (rc)
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -6 -C 1 -c 5 -v -o $PROJECTID-$FILE-rc/$FILE.txt

        # Count rows with values less than 5 in the 4th column in v2 (rc) of unpaired_F
        count_2=0
        for file in "$PROJECTID-$FILE-rc"/*.txt; do
            count_2=$((count_1 + $(awk -F '\t' '$4 < 5 { count++ } END { print count }' "$file")))
        done

        # Compare counts and upload folder with the highest count
        if [ "$count_1" -gt "$count_2" ]; then
            echo "v1 has the highest count: $count_1"
            # upload to aws
            aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        else
            echo "v2 (rc) has the highest count: $count_2"
            # upload to aws
            aws s3 cp $PROJECTID-$FILE-rc/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        fi

        # cleanup
        rm -r $PROJECTID-$FILE/* $PROJECTID-$FILE-rc/*
    fi
fi

if [ "${UNPAIRED_R}" = "TRUE" ]
then
    # check if tronko assign already ran on unpaired_r
    not_exists=$(aws s3api head-object --bucket ednaexplorer --key projects/$PROJECTID/assign/$PRIMER/unpaired_R/$FILE.txt --endpoint-url https://js2.jetstream-cloud.org:8001/ >/dev/null 2>1; echo $?)
    if [ "$((not_exists))" -ne 255 ]; then
        # tronko assign unpaired_r file exists on js2
        echo "Skipping tronko assign unpaired_r for: $FILE"
    else
        # tronko assign unpaired_r does not exist on js2, run
        echo "run unpaired_r: $FILE"
        # download tronko database
        aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        
        # download QC sample unpaired_R
        aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

        # run tronko assign
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -v -o $PROJECTID-$FILE/$FILE.txt

        # Count rows with values less than 5 in the 5th column in v1 of unpaired_R
        count_1=0
        for file in $PROJECTID-$FILE/*.txt; do
            count_1=$((count_1 + $(awk -F '\t' '$5 < 5 { count++ } END { print count }' "$file")))
        done

        # run tronko assign unpaired_R v2 (rc)
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE-rc/$FILE.txt

        # Count rows with values less than 5 in the 5th column in v2 (rc) of unpaired_R
        count_2=0
        for file in "$PROJECTID-$FILE-rc"/*.txt; do
            count_2=$((count_1 + $(awk -F '\t' '$5 < 5 { count++ } END { print count }' "$file")))
        done


        # Compare counts and upload folder with the highest count
        if [ "$count_1" -gt "$count_2" ]; then
            echo "v1 has the highest count: $count_1"
            # upload to aws
            aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        else
            echo "v2 (rc) has the highest count: $count_2"
            # upload to aws
            aws s3 cp $PROJECTID-$FILE-rc/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        fi

        # cleanup
        rm -r $PROJECTID-$FILE/* $PROJECTID-$FILE-rc/*
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
rm -r $PROJECTID-$FILE $PROJECTID-$FILE-rc