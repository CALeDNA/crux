#! /bin/bash

export AWS_MAX_ATTEMPTS=3

OUTPUT="/etc/ben/output"
while getopts "i:p:b:" opt; do
    case $opt in
        i) PROJECTID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        b) BENSERVER="$OPTARG"
        ;;
        *) echo "usage: $0 [-i] [-p] [-b]" >&2
            exit 1 ;;
    esac
done

# download $PROJECTID/QC and samples
aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/QC ${PROJECTID}-$PRIMER/ --exclude "*/*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/samples ${PROJECTID}-$PRIMER/samples --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# download Anacapa
git clone -b cruxv2 https://github.com/CALeDNA/Anacapa.git



# EDIT THESE
BASEDIR="./Anacapa"
DB="$BASEDIR/Anacapa_db"
DATA="./$PROJECTID-$PRIMER/samples"
OUT="./$PROJECTID-$PRIMER/${PROJECTID}QC"

# OPTIONAL
FORWARD="./$PROJECTID-$PRIMER/forward_primers.txt"
REVERSE="./$PROJECTID-$PRIMER/reverse_primers.txt"
LENGTH="./$PROJECTID-$PRIMER/metabarcode_loci_min_merge_length.txt"


# modify forward/reverse to only include $PRIMER information
grep -A 1 ">$PRIMER" "$FORWARD" > tmp
mv tmp "$FORWARD"
grep -A 1 ">$PRIMER" "$REVERSE" > tmp
mv tmp "$REVERSE"

time $DB/anacapa_QC_dada2.sh -i $DATA -o $OUT -d $DB -f $FORWARD -r $REVERSE -m 50 -q 30

# upload $OUT
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/paired/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_F/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_R/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# upload QC logs
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/Run_info s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/Run_info --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


# add ben tronko-assign jobs
# check if paired folder has files
paired_files=$(ls -A "$PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/paired/filtered" | wc -l)
unpaired_F_files=$(ls -A "$PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_F/filtered" | wc -l)
unpaired_R_files=$(ls -A "$PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_R/filtered" | wc -l)
parameters=""
if [ "$paired_files" -gt 0 ]; then
    parameters+="-1"
fi
if [ "$unpaired_F_files" -gt 0 ]; then
    parameters+=" -2"
fi
if [ "$unpaired_R_files" -gt 0 ]; then
    parameters+=" -3"
fi

# add tronko assign job on $PRIMER
/etc/ben/ben add -s $BENSERVER -c "docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -v /tmp:/tmp -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_S3_ACCESS_KEY_ID=$AWS_S3_ACCESS_KEY_ID -e AWS_S3_SECRET_ACCESS_KEY=$AWS_S3_SECRET_ACCESS_KEY -e AWS_S3_DEFAULT_REGION=$AWS_S3_DEFAULT_REGION -e AWS_S3_BUCKET=$AWS_S3_BUCKET --name $PROJECTID-assign-$PRIMER crux /mnt/assign.sh -i $PROJECTID -r $RUNID -p $PRIMER $parameters" $PROJECTID-assign-$PRIMER -o $OUTPUT

# clean up
rm -r /mnt/$PROJECTID-$PRIMER /mnt/Anacapa
