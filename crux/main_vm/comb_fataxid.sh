#! /bin/bash

CONFIG=""
VARS=""
while getopts "c:v:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        v) VARS="$OPTARG"
        ;;
    esac
done

source ${VARS}/${CONFIG}

# download taxdump and taxid2taxonpath script
wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
mkdir taxdump
tar -xf taxdump.tar.gz -C taxdump
rm taxdump.tar.gz
git clone https://github.com/CALeDNA/taxid2taxonpath.git

# combine fa-taxid output by primer and create taxonomy path file
PRIMERS=$(cat ${VARS}/$PRIMERS)
for primer in $PRIMERS
do
    PRIMERNAME=$( echo ${primer} | cut -d ',' -f3 )
    gocmd get -c ${VARS}/${CYVERSE} ${CYVERSE_BASE}/${RUNID}/fa-taxid/${PRIMERNAME}/ .
    cat ${PRIMERNAME}/*.fa >> ${PRIMERNAME}/${PRIMERNAME}.fa
    cat ${PRIMERNAME}/*.fa.taxid >> ${PRIMERNAME}/${PRIMERNAME}.fa.taxid
    find ${PRIMERNAME} -type f -name "*chunk*" -delete
    time python3 taxid2taxonpath/taxid2taxonpath.py -d taxdump/nodes.dmp -m taxdump/names.dmp -e taxdump/merged.dmp -l taxdump/delnodes.dmp -i ${PRIMERNAME}/${PRIMERNAME}.fa.taxid -o ${PRIMERNAME}/${PRIMERNAME}.tax.tsv -c 2 -r 1
    gocmd put -c ${VARS}/${CYVERSE} ${PRIMERNAME}/* ${CYVERSE_BASE}/${RUNID}/fa-taxid/
done