#! /bin/bash

CONFIG=""

while getopts "c:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
    esac
done

cd /mnt

source ${CONFIG}

# run bwa index
# ./bwa_index.sh -n db -i indexes -r ${RUNID} >> logs 2>&1

#TODO
# # download ecopcr fasta files
# gocmd -c ${CYVERSE} get 

# run bwa mem
./bwa_mem.sh -o mem_output -i indexes -r ${RUNID} >> logs 2>&1

# upload log file
gocmd put -c ${CYVERSE} logs /iplant/home/shared/eDNA_Explorer/bwa/logs/logs_${RUNID}.txt