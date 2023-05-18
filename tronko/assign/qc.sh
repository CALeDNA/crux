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

cd $BASEDIR || exit

# If you need additional folders shared into the container, add additional -B arguments below
time ./singularity exec -B $BASEDIR $CONTAINER /bin/bash -c "$DB/anacapa_QC_dada2.sh -i $DATA -o $OUT -d $DB -f $FORWARD -r $REVERSE -e $LENGTH -a nextera -t MiSeq -l -g"

cd || exit

# upload $OUT
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/paired/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_F/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_R/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# add ben tronko-assign jobs

# run tronko assign paired/unpaired_F/R on $PRIMER and sample file
cd $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/unpaired_F/filtered || exit
find . -type f -name '*_F_filt.fastq*' | sed 's/\.\///g' | sed 's/_F_filt\.fastq.*//g' | while read -r filename; do
    if [[ -e "../../paired/filtered/${filename}_F_filt.fastq" ]]; then
        parameters="-1 -2 -3"
    else
        parameters="-2"
    fi
    
    ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$filename crux /mnt/assign.sh -f $filename -i $PROJECTID -p $PRIMER $parameters" $PROJECTID-assign-$filename -o $OUTPUT
done

# add unpaired_R files missed
cd ../../unpaired_R/filtered || exit
find . -type f -name '*_R_filt.fastq*' | sed 's/\.\///g' | sed 's/_R_filt\.fastq.*//g' | while read -r filename; do
    if [[ ! -e "../../paired/filtered/${filename}_R_filt.fastq" ]]; then
        ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PROJECTID-assign-$filename crux /mnt/assign.sh -f $filename -i $PROJECTID -p $PRIMER -3" $PROJECTID-assign-$filename -o $OUTPUT
    else
        echo "Skipping $filename - already in queue."
    fi
done


# clean up
sudo rm -r $PROJECTID-$PRIMER