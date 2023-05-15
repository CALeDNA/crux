#! /bin/bash

OUTPUT="/etc/ben/output"
while getopts "i:p:b:" opt; do
    case $opt in
        i) PROJECTID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        b) BENSERVER="$OPTARG"
        ;;
    esac
done

# download $PROJECTID/QC and samples
aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/QC ${PROJECTID}-$PRIMER/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/samples ${PROJECTID}-$PRIMER/samples --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# download anacapa
aws s3 sync s3://ednaexplorer/Anacapa Anacapa/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# EDIT THESE
BASEDIR="/home/ubuntu/Anacapa" # change to folder you want shared into container
CONTAINER="/home/ubuntu/Anacapa/anacapa-1.5.0.img" # change to full container .img path
DB="/home/ubuntu/Anacapa/Anacapa_db" # change to full path to Anacapa_db
DATA="/home/ubuntu/$PROJECTID-$PRIMER/samples" # change to input data folder (default 12S_test_data inside Anacapa_db)
OUT="/home/ubuntu/$PROJECTID-$PRIMER/${PROJECTID}QC" # change to output data folder

# OPTIONAL
FORWARD="$PROJECTID-$PRIMER/forward_primers.txt"
REVERSE="$PROJECTID-$PRIMER/reverse_primers.txt"
LENGTH="$PROJECTID-$PRIMER/metabarcode_loci_min_merge_length.txt"

cd $BASEDIR

# If you need additional folders shared into the container, add additional -B arguments below
time ./singularity exec -B $BASEDIR $CONTAINER /bin/bash -c "$DB/anacapa_QC_dada2.sh -i $DATA -o $OUT -d $DB -f $FORWARD -r $REVERSE -e $LENGTH -a truseq -t MiSeq -l -g"

cd

# upload $OUT
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/paired/filtered s3://ednaexplorer/projects/$PROJECTID/$PRIMER/QC/paired --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_F/filtered s3://ednaexplorer/projects/$PROJECTID/$PRIMER/QC/unpaired_F --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_R/filtered s3://ednaexplorer/projects/$PROJECTID/$PRIMER/QC/unpaired_R --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# add ben tronko-assign jobs

# run tronko assign paired/unpaired_F/R on $PRIMER and sample file {}
cd $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/paired/filtered

find . -type f -name '*_F_filt.fastq*' | sed 's/\.\///g' | sed 's/_F_filt\.fastq.*//g' | ben add -s $BENSERVER -c "cd crux; docker run -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$PRIMER crux /mnt/assign.sh -f {} -i $PROJECTID -p $PRIMER -1 -2 -3" $PROJECTID-assign-{}-$PRIMER -o $OUTPUT

cd

# # unpaired_F
# cd $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_F/filtered

# find . -type f -name '*_F_filt.fastq*' | sed 's/\.\///g' | sed 's/_F_filt\.fastq.*//g' | ben add -s $BENSERVER -c "cd crux; docker run -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$PRIMER crux /mnt/assign.sh -f {} -i $PROJECTID -p $PRIMER -2" $PROJECTID-assign-{}-$PRIMER -o $OUTPUT

# cd


# # unpaired_R
# cd $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_R/filtered

# find . -type f -name '*_R_filt.fastq*' | sed 's/\.\///g' | sed 's/_R_filt\.fastq.*//g' | ben add -s $BENSERVER -c "cd crux; docker run -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$PRIMER crux /mnt/assign.sh -f {} -i $PROJECTID -p $PRIMER -3" $PROJECTID-assign-{}-$PRIMER -o $OUTPUT

# cd


# clean up
sudo rm -r $PROJECTID-$PRIMER