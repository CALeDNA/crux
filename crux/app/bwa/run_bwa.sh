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
mkdir ecopcr
mkdir mem_output/

# run bwa index
./bwa_index.sh -n db -i indexes -r ${RUNID} >> logs 2>&1

# download ecopcr fasta files and combine them
gocmd -c ${CYVERSE} get /iplant/home/shared/eDNA_Explorer/ecopcr/${RUNID}/ ecopcr/
for d in ecopcr/${RUNID}/*/
do
    cat ${d}*.fasta > "${d%/}".fasta
done

# run bwa mem
./bwa_mem.sh -o mem_output -i indexes -r ${RUNID} -h ${HOSTNAME} >> logs 2>&1

# upload log file
gocmd put -c ${CYVERSE} logs /iplant/home/shared/eDNA_Explorer/bwa/logs/logs_${RUNID}.txt