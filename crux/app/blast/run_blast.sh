#! /bin/bash

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

# download ecopcr fasta files and combine them
gocmd -c ${CYVERSE} get ${CYVERSE_BASE}/${RUNID}/ecopcr .
for d in ecopcr/*/
do
    cat ${d}*.fasta > "${d%/}".fasta
done

# run ntblast
./ntblast.sh -c ${CONFIG} -h ${HOSTNAME} -v ${VARS}