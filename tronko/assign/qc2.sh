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
# add tronko assign paired/unpaired_F/R on $PRIMER and sample file
cd $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_F/filtered || exit
find . -type f -name '*_F_filt.fastq.gz' | sed 's/\.\///g' | sed 's/_F_filt\.fastq.gz//g' | while read -r filename; do
    if [[ -e "../paired/${filename}_F_filt.fastq.gz" ]]; then
        parameters="-1 -2 -3"
    else
        parameters="-2"
    fi;
    
    /etc/ben/ben add -s /tmp/ben-assign -c "docker run --rm -t -v /home/ubuntu/crux/tronko/assign:/mnt -v /home/ubuntu/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$PRIMER-$filename crux /mnt/assign.sh -f $filename -i $PROJECTID -p $PRIMER $parameters" $PROJECTID-assign-$PRIMER-$filename -f main -o $OUTPUT;
done

# add unpaired_R files missed
cd ../../unpaired_R/filtered || exit
find . -type f -name '*_R_filt.fastq.gz' | sed 's/\.\///g' | sed 's/_R_filt\.fastq.gz//g' | while read -r filename; do
    if [[ ! -e "../paired/${filename}_R_filt.fastq.gz" ]]; then
        /etc/ben/ben add -s /tmp/ben-assign -c "docker run --rm -t -v /home/ubuntu/crux/tronko/assign:/mnt -v /home/ubuntu/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$PRIMER-$filename crux /mnt/assign.sh -f $filename -i $PROJECTID -p $PRIMER -3" $PROJECTID-assign-$PRIMER-$filename -f main -o $OUTPUT;
    else
        echo "Skipping $filename - already in queue.";   
    fi
done

# clean up
rm -r /mnt/$PROJECTID-$PRIMER /mnt/Anacapa
