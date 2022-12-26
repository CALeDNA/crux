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
aws s3 sync s3://ednaexplorer/crux/${RUNID}/ecopcr . --endpoint-url https://js2.jetstream-cloud.org:8001/
# gocmd -c ${CYVERSE} get ${CYVERSE_BASE}/${RUNID}/ecopcr .
for d in ecopcr/*/
do
    cat ${d}*.fasta > "${d%/}".fasta
done

# get file with nt cyverse urls
aws s3 cp s3://ednaexplorer/crux/${NTFILE} . --endpoint-url https://js2.jetstream-cloud.org:8001/
# gocmd get -c ${CYVERSE} "/iplant/home/shared/eDNA_Explorer/crux/${NTFILE}" .

# run ntblast
./ntblast.sh -c ${CONFIG} -h ${HOSTNAME} -v ${VARS}