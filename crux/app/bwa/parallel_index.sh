#! /bin/bash

set -x

while getopts "a:b:f:c:" opt; do
    case $opt in
        a) ALGO="$OPTARG"
        ;;
        b) LENGTH="$OPTARG" 
        ;;
        f) FILE="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
    esac
done

source ${CONFIG}

# build index
time bwa index -a ${ALGO} -b ${LENGTH} ${FILE}

# upload index to cyverse
for i in {1..5}; do gocmd put -c ${CYVERSE} ${FILE}* ${CYVERSE_BASE}/${RUNID}/bwa-index/ && echo "Successful gocmd upload" && break || sleep 15; done

# delete index
rm ${FILE}*