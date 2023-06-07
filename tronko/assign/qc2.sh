#! /bin/bash
set -x

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
#TODO switch from s3 to git clone
git clone -b cruxv2 https://github.com/CALeDNA/Anacapa.git
# should already be dl from Dockerfile
# aws s3 sync s3://ednaexplorer/Anacapa Anacapa/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/



# EDIT THESE
BASEDIR="~/Anacapa"
DB="$BASEDIR/Anacapa_db"
DATA="~/$PROJECTID-$PRIMER/samples"
OUT="~/$PROJECTID-$PRIMER/${PROJECTID}QC"

# OPTIONAL
FORWARD="~/$PROJECTID-$PRIMER/forward_primers.txt"
REVERSE="~/$PROJECTID-$PRIMER/reverse_primers.txt"
LENGTH="~/$PROJECTID-$PRIMER/metabarcode_loci_min_merge_length.txt"
# FORWARD="/home/ubuntu/crux/tronko/assign/$PROJECTID-$PRIMER/forward_primers.txt"
# REVERSE="/home/ubuntu/crux/tronko/assign/$PROJECTID-$PRIMER/reverse_primers.txt"
# LENGTH="/home/ubuntu/crux/tronko/assign/$PROJECTID-$PRIMER/metabarcode_loci_min_merge_length.txt"


# modifiy forward/reverse to only include $PRIMER information
grep -A 1 ">$PRIMER" "$FORWARD" > tmp
mv tmp "$FORWARD"
grep -A 1 ">$PRIMER" "$REVERSE" > tmp
mv tmp "$REVERSE"


cd $BASEDIR || exit

time $DB/anacapa_QC_dada2.sh -i $DATA -o $OUT -d $DB -f $FORWARD -r $REVERSE -m 50 -q 30

cd

# upload $OUT
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/paired/filtered s3://ednaexplorer/projects/$PROJECTID/QC/OUT/$PRIMER/paired --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_F/filtered s3://ednaexplorer/projects/$PROJECTID/QC/OUT/$PRIMER/unpaired_F --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_R/filtered s3://ednaexplorer/projects/$PROJECTID/QC/OUT/$PRIMER/unpaired_R --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# upload QC logs
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/Run_info s3://ednaexplorer/projects/$PROJECTID/QC/Run_info --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


# add ben tronko-assign jobs
# run tronko assign paired/unpaired_F/R on $PRIMER and sample file
cd $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_F/filtered || exit
find . -type f -name '*_F_filt.fastq*' | sed 's/\.\///g' | sed 's/_F_filt\.fastq.*//g' | while read -r filename; do
    if [[ -e "../../paired/filtered/${filename}_F_filt.fastq" ]]; then
        parameters="-1 -2 -3"
    else
        parameters="-2"
    fi
    
    ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$filename crux /mnt/assign.sh -f $filename -i $PROJECTID -p $PRIMER $parameters" $PROJECTID-assign-$filename -f main -o $OUTPUT
done

# add unpaired_R files missed
cd ../../unpaired_R/filtered || exit
find . -type f -name '*_R_filt.fastq*' | sed 's/\.\///g' | sed 's/_R_filt\.fastq.*//g' | while read -r filename; do
    if [[ ! -e "../../paired/filtered/${filename}_R_filt.fastq" ]]; then
        ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$filename crux /mnt/assign.sh -f $filename -i $PROJECTID -p $PRIMER -3" $PROJECTID-assign-$filename -f main -o $OUTPUT
    else
        echo "Skipping $filename - already in queue."
    fi
done


# clean up
rm -r $PROJECTID-$PRIMER
