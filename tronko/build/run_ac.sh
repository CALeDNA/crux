#!/bin/bash
set -x
set -o allexport

export AWS_MAX_ATTEMPTS=3

max_length=20000
cutoff_length=25000
FIRST="FALSE"
OUTPUT="/etc/ben/output"
while getopts "d:t:f:p:j:i:b:B:1?" opt; do
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

# step 1: download dereplicated fasta and taxa file
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
