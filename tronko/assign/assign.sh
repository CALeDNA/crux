#! /bin/bash

OUTPUT="/etc/ben/output"
PAIRED=""
UNPAIRED_F=""
UNPAIRED_R=""
while getopts "f:i:p:1:2:3:" opt; do
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

source /vars/crux_vars.sh # to get tronko db run ID

# download tronko database for $PRIMER
aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


if [ "${PAIRED}" = "TRUE" ]
then
    # download QC sample paired files
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/$PRIMER/QC/paired/ $PROJECTID/ --exclude '*' --include '${FILE}*' --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID/tronkodb/reference_tree.txt.gz -a $PROJECTID/tronkodb/$PRIMER.fasta -p -z -w -q -1 $PROJECTID/${FILE}_F_filt.fastq -2 $PROJECTID/${FILE}_R_filt.fastq -6 -C 1 -c 5 -o $PROJECTID/$FILE.txt

    # upload to aws
    aws s3 cp $PROJECTID/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/$PRIMER/assign/paired/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm $PROJECTID/*
fi

if [ "${UNPAIRED_F}" = "TRUE" ]
then
    # download QC sample unpaired_F
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/$PRIMER/QC/unpaired_F/ $PROJECTID/ --exclude '*' --include '${FILE}*' --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID/tronkodb/reference_tree.txt.gz -a $PROJECTID/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID/${FILE}_F_filt.fastq -6 -C 1 -c 5 -o $PROJECTID/$FILE.txt

    # upload to aws
    aws s3 cp $PROJECTID/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/$PRIMER/assign/unpaired_F/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm $PROJECTID/*
fi

if [ "${UNPAIRED_R}" = "TRUE" ]
then
    # download QC sample unpaired_R
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/$PRIMER/QC/unpaired_R/ $PROJECTID/ --exclude '*' --include '${FILE}*' --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID/tronkodb/reference_tree.txt.gz -a $PROJECTID/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID/${FILE}_R_filt.fastq -6 -C 1 -c 5 -o $PROJECTID/$FILE.txt

    # upload to aws
    aws s3 cp $PROJECTID/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/$PRIMER/assign/unpaired_R/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm $PROJECTID/*
fi


# cleanup
sudo rm -r $PROJECTID