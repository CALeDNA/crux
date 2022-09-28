#! /bin/bash

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
gocmd put -c ${CYVERSE} ${FILE}* ${CYVERSE_BASE}/${RUNID}/bwa-index/
# delete index
rm ${FILE}*