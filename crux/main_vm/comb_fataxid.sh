#! /bin/bash
set -x

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

# download nucl acc2taxid
wget -q -c --tries=0 ftp://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz
gunzip nucl_gb.accession2taxid.gz

# combine fa-taxid output by primer and create taxonomy path file
PRIMERS=$(cat ${VARS}/$PRIMERS)
for primer in $PRIMERS
do
    PRIMERNAME=$( echo ${primer} | cut -d ',' -f3 )
    gocmd get -c ${VARS}/${CYVERSE} ${CYVERSE_BASE}/${RUNID}/fa-taxid/${PRIMERNAME}/ .
    cat ${PRIMERNAME}/*.fa >> ${PRIMERNAME}/${PRIMERNAME}.fa
    # cat ${PRIMERNAME}/*.fa.taxid >> ${PRIMERNAME}/${PRIMERNAME}.fa.taxid
    find ${PRIMERNAME} -type f -name "*chunk*" -delete
    # remove repeat taxid
    time python3 fix_fasta.py --fasta ${PRIMERNAME}/${PRIMERNAME}.fa --output ${PRIMERNAME}.fa --nucltaxid nucl_gb.accession2taxid --log log_missed_taxid
    # get taxon path
    time python3 taxid2taxonpath/taxid2taxonpath.py -d taxdump/nodes.dmp -m taxdump/names.dmp -e taxdump/merged.dmp -l taxdump/delnodes.dmp -i ${PRIMERNAME}.fa.taxid -o ${PRIMERNAME}.tax.tsv -c 2 -r 1
    # gocmd put -c ${VARS}/${CYVERSE} ${PRIMERNAME}/* ${CYVERSE_BASE}/${RUNID}/fa-taxid/
    for i in {1..5}; do gocmd put -c ${VARS}/${CYVERSE} ${PRIMERNAME}.fa ${CYVERSE_BASE}/${RUNID}/fa-taxid/${PRIMERNAME}.fa && echo "Successful gocmd upload" && break || sleep 15; done
    for i in {1..5}; do gocmd put -c ${VARS}/${CYVERSE} ${PRIMERNAME}.tax.tsv ${CYVERSE_BASE}/${RUNID}/fa-taxid/${PRIMERNAME}.tax.tsv && echo "Successful gocmd upload" && break || sleep 15; done
done

# upload missed taxid
for i in {1..5}; do gocmd put -c ${VARS}/${CYVERSE} log_missed_taxid ${CYVERSE_BASE}/${RUNID}/logs/log_missed_taxid && echo "Successful gocmd upload" && break || sleep 15; done