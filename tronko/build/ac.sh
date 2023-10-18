#!/bin/bash
set -o allexport

export AWS_MAX_ATTEMPTS=3

max_length=20000
cutoff_length=25000
FIRST="FALSE"
OUTPUT="/etc/ben/output"
while getopts "d:t:f:p:j:i:b:B:k:s:r:1?" opt; do
    case $opt in
        d) FOLDER="$OPTARG" # folder of last run
        ;;
        t) TAXA="$OPTARG"
        ;;
        f) FASTA="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        j) JOB="$OPTARG" # folder of this run
        ;;
        i) RUNID="$OPTARG"
        ;;
        b) ACSERVER="$OPTARG"
        ;;
        B) NEWICKSERVER="$OPTARG"
        ;;
        1) FIRST="TRUE"
        ;;
    esac
done


cd /mnt
mkdir -p $JOB/dir

# download dereplicated fasta and taxa file
if [ "${FIRST}" = "TRUE" ]; then
    aws s3 cp s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/dereplicated/$PRIMER.fasta $JOB/$PRIMER.fasta --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/dereplicated/$PRIMER.tax.tsv $JOB/${PRIMER}_taxonomy.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
else
    aws s3 cp s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER/$FASTA $JOB/$PRIMER.fasta --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER/$TAXA $JOB/${PRIMER}_taxonomy.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
fi

fasta=$JOB/$PRIMER.fasta
taxa=$JOB/${PRIMER}_taxonomy.txt
len=$(wc -l ${taxa} | cut -d ' ' -f1)

if (( $len > $cutoff_length ))
then
    # run ancestral clust
    bin_size=$(( ($len + $max_length - 1) / $max_length ))
    time ancestralclust -i $fasta -t $taxa -d $JOB/dir -f -u -r 1000 -b $bin_size -c 4 -p 75
else
    cp $fasta $JOB/dir/0.fasta
    cp $taxa $JOB/dir/0_taxonomy.txt
fi

# rm orig taxa and fasta files
rm $taxa $fasta

# upload ac
aws s3 sync $JOB/dir s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$JOB --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# add ac jobs to queue
added_job="FALSE"
for file in $JOB/dir/*taxonomy.txt
do
    len=$(wc -l $file | cut -d ' ' -f1)
    if (( $len > $cutoff_length ))
    then
        added_job="TRUE"
        folder=$( echo $file | rev | cut -d"/" -f3 | rev )
        taxa=$( basename $file )
        job=$( echo $taxa | sed 's/_[^_]*$//g')
        fasta="$job.fasta"
        job=$(printf '%02d' "$job") # add leading zero
        job="$folder$job" # -> ex: 12S_MiFish_U-ac-001203

        ben add -s $ACSERVER -c "docker run --rm -t -v ~/crux/tronko/build:/mnt -v ~/crux/crux/vars:/vars -v /tmp:/tmp -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $JOB-$RUNID crux /mnt/ac.sh -d $folder -t $taxa -f $fasta -p $PRIMER -j $job -i $RUNID -b $ACSERVER -B $NEWICKSERVER" $job-$RUNID -o $OUTPUT  
    fi
done

# if new output folder added a job, skip. otherwise start ac2newick
if [ "$added_job" = "FALSE" ]
then
    suffix=$( echo $JOB | rev | cut -d'-' -f1 | rev | tr -dc '0-9' )
    job="$PRIMER-newick$suffix"
    ben add -s $NEWICKSERVER -c "docker run --rm -t -v ~/crux/tronko/build:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $job-$RUNID crux /mnt/ac2newick.sh -d $JOB -j $job -i $RUNID -p $PRIMER" $job-$RUNID -o $OUTPUT
fi

# delete local files
rm -r $JOB

# delete recursed file from bucket
if [ "${FIRST}" != "TRUE" ]; then
    aws s3 rm s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER/$FASTA --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 rm s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER/$TAXA --endpoint-url https://js2.jetstream-cloud.org:8001/
fi

# check if parent bucket is newick ready
newick_ready="TRUE"
if [ "${FIRST}" != "TRUE" ]; then
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER $JOB/$FOLDER --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    for file in $JOB/$FOLDER/*taxonomy.txt
    do
        echo $file
        len=$(wc -l ${file} | cut -d ' ' -f1)
        if (( $len > $cutoff_length ))
        then
            newick_ready="FALSE"
            break
        fi
    done
else
    newick_ready="FALSE"
fi

if [ "$newick_ready" = "TRUE" ]
then
    suffix=$( echo $FOLDER | rev | cut -d'-' -f1 | rev | tr -dc '0-9' )
    if [ "$FIRST" = "TRUE" ]
    then
        echo "parent folder is root ancestralclust folder"
    else
        job="$PRIMER-newick$suffix"
        ben add -s $NEWICKSERVER -c "docker run --rm -t -v ~/crux/tronko/build:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $job-$RUNID crux /mnt/ac2newick.sh -d $FOLDER -j $job -i $RUNID -p $PRIMER" $job-$RUNID -o $OUTPUT
    fi
fi
