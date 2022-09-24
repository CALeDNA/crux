#! /bin/bash

CONFIG=""

while getopts "c:h:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
    esac
done

cd /mnt

source ${CONFIG}

# create empty folders
mkdir db/
mkdir ecopcr/
mkdir mem_output/
mkdir indexes/

# download ecopcr fasta files and combine them
gocmd -c ${CYVERSE} get /iplant/home/shared/eDNA_Explorer/ecopcr/${RUNID}/ ecopcr/
for d in ecopcr/${RUNID}/*/
do
    cat ${d}*.fasta > "${d%/}".fasta
done

# run bwa index
./bwa_index.sh -n db -i indexes -r ${RUNID} -h ${HOSTNAME} >> logs 2>&1

# run bwa mem
./bwa_mem.sh -o mem_output -i indexes -r ${RUNID} -h ${HOSTNAME} -t ${THREADS} -c ${CYVERSE} >> logs 2>&1

# upload log file
gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/bwa/logs/${RUNID}
gocmd put -c ${CYVERSE} logs /iplant/home/shared/eDNA_Explorer/bwa/logs/${RUNID}/bwa_chunk${HOSTNAME}.txt