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

source /vars/crux_vars.sh # to get tronko db run ID


if [ "${PAIRED}" = "TRUE" ]
then
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample paired files
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -p -z -w -q -1 $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -2 $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt

    # upload to aws
    aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm -r $PROJECTID-$FILE/*
fi

if [ "${UNPAIRED_F}" = "TRUE" ]
then
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample unpaired_F
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt

    # upload to aws
    aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm -r $PROJECTID-$FILE/*
fi

if [ "${UNPAIRED_R}" = "TRUE" ]
then
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample unpaired_R
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt

    # upload to aws
    aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm -r $PROJECTID-$FILE/*
fi


# cleanup
rm -r $PROJECTID-$FILE