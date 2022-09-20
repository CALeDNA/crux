#!/bin/bash

CONFIG=""
while getopts "c:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
    esac
done

cd /mnt

# activate conda env
export PATH="/usr/local/miniconda/bin:$PATH";

source ${CONFIG}

# conda init bash;

# . /root/.bashrc

# conda activate base;

# HOSTNAME=$(hostname | tr -dc '0-9')
HOSTNAME="19"
OUTPUT="fasta_output"

# download link files
gocmd get -c ${CYVERSE} /iplant/home/shared/eDNA_Explorer/urls/${RUNID}/chunk${HOSTNAME}/ .

# run obi_ecopcr.sh on every links file
find chunk${HOSTNAME}/* | parallel -I% --tag --max-args 1 -P ${THREADS} ./obi_ecopcr.sh -g % -p ${PRIMERS} -o ${OUTPUT} -b % -e 3 -s 100 -l 10000 >> logs 2>&1

gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/ecopcr/${RUNID}
gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/ecopcr/logs/${RUNID}
gocmd put -c ${CYVERSE} logs /iplant/home/shared/eDNA_Explorer/ecopcr/logs/${RUNID}/ecopcr_chunk${HOSTNAME}.txt
# combine primer fasta files into one
for primer in $(cat $PRIMERS)
do
    PRIMERNAME=$( echo ${primer} | cut -d ',' -f3 )
    find ${OUTPUT}/ -type f -name "*${PRIMERNAME}.fasta" | xargs -I{} cat {} >> ${PRIMERNAME}_${HOSTNAME}.fasta

    # upload combined fasta file to cyverse
    gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/ecopcr/${RUNID}/${PRIMERNAME}
    gocmd put -c ${CYVERSE} ${PRIMERNAME}_${HOSTNAME}.fasta /iplant/home/shared/eDNA_Explorer/ecopcr/${RUNID}/${PRIMERNAME}/chunk${HOSTNAME}.fasta
    rm ${PRIMERNAME}_${HOSTNAME}.fasta
done

# cleanup
rm ${OUTPUT}/*
rm -r taxdump
rm logs
