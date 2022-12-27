#!/bin/bash

set -x

CONFIG=""
VARS="/vars"
while getopts "c:h:v:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        v) VARS="$OPTARG"
        ;;
    esac
done

cd /mnt
cp ${VARS}/* .
# activate conda env
export PATH="/usr/local/miniconda/bin:$PATH";

source ${CONFIG}

# conda init bash;

# . /root/.bashrc

# conda activate base;
OUTPUT="fasta_output"
mkdir ${OUTPUT}

# download link files
aws s3 sync s3://ednaexplorer/crux/${RUNID}/urls/chunk${HOSTNAME}/ ./chunk${HOSTNAME} --endpoint-url https://js2.jetstream-cloud.org:8001/
# gocmd get -c ${CYVERSE} ${CYVERSE_BASE}/${RUNID}/urls/chunk${HOSTNAME}/ .

# run obi_ecopcr.sh on every links file
find chunk${HOSTNAME}/* | parallel -I% --tag --max-args 1 -P ${THREADS} ./obi_ecopcr.sh -g % -p ${PRIMERS} -o ${OUTPUT} -b % -e ${ERROR} -c ${CONFIG} >> logs 2>&1

aws s3 cp logs s3://ednaexplorer/crux/${RUNID}/logs/ecopcr_chunk${HOSTNAME}.txt --endpoint-url https://js2.jetstream-cloud.org:8001/
# gocmd put -c ${CYVERSE} logs ${CYVERSE_BASE}/${RUNID}/logs/ecopcr_chunk${HOSTNAME}.txt
# combine primer fasta files into one
for primer in $(cat $PRIMERS)
do
    PRIMERNAME=$( echo ${primer} | cut -d ',' -f3 )
    find ${OUTPUT}/ -type f -name "*${PRIMERNAME}.fasta" | xargs -I{} cat {} >> ${PRIMERNAME}_${HOSTNAME}.fasta

    # upload combined fasta file to cyverse
    aws s3 cp ${PRIMERNAME}_${HOSTNAME}.fasta s3://ednaexplorer/crux/${RUNID}/ecopcr/${PRIMERNAME}/chunk${HOSTNAME}.fasta --endpoint-url https://js2.jetstream-cloud.org:8001/
    # gocmd -c ${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/ecopcr/${PRIMERNAME}
    # for i in {1..5}; do gocmd put -c ${CYVERSE} ${PRIMERNAME}_${HOSTNAME}.fasta ${CYVERSE_BASE}/${RUNID}/ecopcr/${PRIMERNAME}/chunk${HOSTNAME}.fasta && echo "Successful gocmd upload" && break || sleep 15; done
    rm ${PRIMERNAME}_${HOSTNAME}.fasta
done

# cleanup
rm ${OUTPUT}/*
rm -r taxdump
rm logs
