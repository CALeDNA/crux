
#!/bin/bash

GENBANK="" # file containing genbank links
PRIMERS="" # file containing list of primers
OUTPUT="" # folder to output fasta files
BATCHTAG="" # batch tag
ERROR="" # ecopcr error
MINLENGTH="" # ecopcr min length
MAXLENGTH="" # ecopcr max length
RUNID="" # run ID

while getopts "g:p:o:b:e:s:l:i:" opt; do
    case $opt in
        g) GENBANK="$OPTARG"
        ;;
        p) PRIMERS="$OPTARG"
        ;;
        o) OUTPUT="$OPTARG"
        ;;
        b) BATCHTAG="$(basename $OPTARG)"
        ;;
        e) ERROR="$OPTARG"
        ;;
        s) MINLENGTH="$OPTARG"
        ;;
        l) MAXLENGTH="$OPTARG"
        ;;
        i) RUNID="$OPTARG"
        ;;
    esac
done

# activate conda env
#export PATH="/home/ubuntu/miniconda3/bin:$PATH"; 
conda activate ecopcr;

HOSTNAME=$(hostname)

source .aws/credentials
aws configure set aws_access_key_id ${aws_access_key_id}
aws configure set aws_secret_access_key ${aws_secret_access_key}
aws configure set region ${region}

# download link files
aws s3 sync s3://ednaexplorer/test1000/${HOSTNAME} links --endpoint-url https://js2.jetstream-cloud.org:8001/

# run obi_ecopcr.sh on every links file
find links/* | parallel -I% --tag --max-args 1 -P 8 ./obi_ecopcr.sh -g % -p primers -o fasta_output -b % -e 3 -s 100 -l 10000 >> logs 2>&1

# combine primer fasta files into one
file="primers"
primers=$(cat $file)
for primer in $primers
do
    PRIMERNAME=$( echo ${primer} | cut -d ',' -f3 )
    find fasta_output -type f -name "*${PRIMERNAME}.fasta" | xargs -I{} cat {} >> ${PRIMERNAME}_${HOSTNAME}.fasta

    # upload combined fasta file to data store
    aws s3 sync ${PRIMERNAME}_${HOSTNAME}.fasta s3://ednaexplorer/${RUNID}/${PRIMERNAME}/ecopcr/${HOSTNAME}/${PRIMERNAME}_${HOSTNAME}.fasta --endpoint-url https://js2.jetstream-cloud.org:8001/
    rm ${PRIMERNAME}_${HOSTNAME}.fasta
done

# cleanup
rm fasta_output/*
rm -r taxdump
rm logs
