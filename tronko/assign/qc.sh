#! /bin/bash

export AWS_MAX_ATTEMPTS=3

OUTPUT="/etc/ben/output"
RUNID="2023-04-07"
while getopts "i:p:b:a:k:s:r:K:S:R:B:" opt; do
    case $opt in
        i) PROJECTID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        b) BENSERVER="$OPTARG"
        ;;
        a) ADAPTER="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
        K) AWS_S3_ACCESS_KEY_ID="$OPTARG"
        ;;
        S) AWS_S3_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        R) AWS_S3_DEFAULT_REGION="$OPTARG"
        ;;
        B) AWS_S3_BUCKET="$OPTARG"
        ;;
        *) echo "usage: $0 [-i] [-p] [-b] [-k] [-s] [-r] [-K] [-S] [-R] [-B]" >&2
            exit 1 ;;
    esac
done

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

cd ~/crux/tronko/assign || exit

# check if QC already ran on this primer
dir_exists=$(aws s3 ls s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired/ --endpoint-url https://js2.jetstream-cloud.org:8001/ | wc -l)
if [ "$dir_exists" -gt 0 ]; then
    # QC exists on js2 for this project
    echo "Skipping QC step for: $PROJECTID-$PRIMER"

    # download QC files
    mkdir -p $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/paired/filtered
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/paired/filtered --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    mkdir -p $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_F/filtered
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_F/filtered --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    mkdir -p $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_R/filtered
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_R/filtered --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
else
    # download $PROJECTID/QC and samples
    aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/QC ${PROJECTID}-$PRIMER/ --exclude "*/*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/samples ${PROJECTID}-$PRIMER/samples --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # download anacapa
    git clone -b cruxrachel https://github.com/CALeDNA/Anacapa.git
    # download singularity & image
    aws s3 sync s3://ednaexplorer/anacapa/ Anacapa/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


    # EDIT THESE
    BASEDIR="/home/ubuntu/crux/tronko/assign/Anacapa" # change to folder you want shared into container
    CONTAINER="$BASEDIR/anacapa-1.5.0.img" # change to full container .img path
    DB="/home/ubuntu/crux/tronko/assign/Anacapa/Anacapa_db" # change to full path to Anacapa_db
    DATA="/home/ubuntu/crux/tronko/assign/$PROJECTID-$PRIMER/samples" # change to input data folder (default 12S_test_data inside Anacapa_db)
    OUT="/home/ubuntu/crux/tronko/assign/$PROJECTID-$PRIMER/${PROJECTID}QC" # change to output data folder

    # OPTIONAL
    FORWARD="/home/ubuntu/crux/tronko/assign/$PROJECTID-$PRIMER/forward_primers.txt"
    REVERSE="/home/ubuntu/crux/tronko/assign/$PROJECTID-$PRIMER/reverse_primers.txt"
    LENGTH="/home/ubuntu/crux/tronko/assign/$PROJECTID-$PRIMER/metabarcode_loci_min_merge_length.txt"


    # modifiy forward/reverse to only include $PRIMER information
    grep -A 1 ">$PRIMER" "$FORWARD" > tmp
    mv tmp "$FORWARD"
    grep -A 1 ">$PRIMER" "$REVERSE" > tmp
    mv tmp "$REVERSE"


    cd $BASEDIR || exit

    # If you need additional folders shared into the container, add additional -B arguments below
    chmod +x $BASEDIR/singularity/bin/* $BASEDIR/singularity/libexec/singularity/bin/* $DB/anacapa_QC_dada2.sh
    time $BASEDIR/singularity/bin/singularity exec -B $BASEDIR $CONTAINER /bin/bash -c "$DB/anacapa_QC_dada2.sh -i $DATA -o $OUT -d $DB -f $FORWARD -r $REVERSE -e $LENGTH -a $ADAPTER -t MiSeq -l"

    cd ~/crux/tronko/assign || exit

    # upload $OUT
    aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/paired/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_F/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_R/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # upload QC logs
    aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/Run_info s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/Run_info --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
fi

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
/etc/ben/ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -v /tmp:/tmp -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_S3_ACCESS_KEY_ID=$AWS_S3_ACCESS_KEY_ID -e AWS_S3_SECRET_ACCESS_KEY=$AWS_S3_SECRET_ACCESS_KEY -e AWS_S3_DEFAULT_REGION=$AWS_S3_DEFAULT_REGION -e AWS_S3_BUCKET=$AWS_S3_BUCKET --name $PROJECTID-assign-$PRIMER crux /mnt/assign.sh -i $PROJECTID -r $RUNID -p $PRIMER $parameters" $PROJECTID-assign-$PRIMER -o $OUTPUT

# clean up
sudo rm -r $PROJECTID-$PRIMER