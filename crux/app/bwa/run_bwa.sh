#! /bin/bash

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
source ${CONFIG}

# create empty folders
mkdir db/
mkdir ecopcr/
mkdir mem_output/
mkdir indexes/

# download ecopcr fasta files and combine them
gocmd -c ${CYVERSE} get ${CYVERSE_BASE}/${RUNID}/ecopcr ecopcr/
for d in ecopcr/${RUNID}/*/
do
    cat ${d}*.fasta > "${d%/}".fasta
done

# run bwa index
./bwa_index.sh -n db -i indexes -r ${RUNID} -h ${HOSTNAME} -c ${CONFIG} >> logs 2>&1

# run bwa mem
./bwa_mem.sh -o mem_output -i indexes -r ${RUNID} -h ${HOSTNAME} -t ${THREADS} -c ${CONFIG} >> logs 2>&1

# upload log file
gocmd put -c ${CYVERSE} logs ${CYVERSE_BASE}/${RUNID}/logs/bwa_chunk${HOSTNAME}.txt