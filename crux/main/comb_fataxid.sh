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

# combine fa-taxid output by primer and create taxonomy path file
PRIMERS=$(cat ${VARS}/$PRIMERS)
for primer in $PRIMERS
do
    PRIMERNAME=$( echo ${primer} | cut -d ',' -f3 )
    aws s3 sync s3://ednaexplorer/crux/${RUNID}/fa-taxid/${PRIMERNAME}/ ${PRIMERNAME}/ --endpoint-url https://js2.jetstream-cloud.org:8001/
    cat ${PRIMERNAME}/*.fa >> ${PRIMERNAME}/${PRIMERNAME}.fa
    find ${PRIMERNAME} -type f -name "*chunk*" -delete
    # remove repeat taxid
    time python3 fix-fasta.py --input ${PRIMERNAME}/${PRIMERNAME}.fa --output ${PRIMERNAME}.fa --log log_missed_taxid
    # remove ambiguous bp
    removeAmbiguousfromFa.pl ${PRIMERNAME}.fa > ${PRIMERNAME}_ambiguousremoved.fa
    mv ${PRIMERNAME}_ambiguousremoved.fa ${PRIMERNAME}.fa
    # get taxon path
    time python3 taxid2taxonpath/taxid2taxonpath.py -d taxdump/nodes.dmp -m taxdump/names.dmp -e taxdump/merged.dmp -l taxdump/delnodes.dmp -i ${PRIMERNAME}.fa.taxid -o ${PRIMERNAME}.tax.tsv -c 2 -r 1
    # gocmd put -c ${VARS}/${CYVERSE} ${PRIMERNAME}/* ${CYVERSE_BASE}/${RUNID}/fa-taxid/
    aws s3 cp ${PRIMERNAME}.fa s3://ednaexplorer/crux/${RUNID}/fa-taxid/${PRIMERNAME}.fa --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp ${PRIMERNAME}.tax.tsv  s3://ednaexplorer/crux/${RUNID}/fa-taxid/${PRIMERNAME}.tax.tsv  --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp ${PRIMERNAME}.fa.taxid s3://ednaexplorer/crux/${RUNID}/fa-taxid/${PRIMERNAME}.fa.taxid --endpoint-url https://js2.jetstream-cloud.org:8001/

    aws s3 cp ${PRIMERNAME}.fa s3://ednaexplorer/tronko/${RUNID}/${PRIMERNAME}/${PRIMERNAME}.fasta --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp ${PRIMERNAME}.tax.tsv  s3://ednaexplorer/tronko/${RUNID}/${PRIMERNAME}/${PRIMERNAME}_taxonomy.txt --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # cleanup
    rm -r ${PRIMERNAME}* 
done

# upload missed taxid
aws s3 cp log_missed_taxid s3://ednaexplorer/crux/${RUNID}/logs/log_missed_taxid --endpoint-url https://js2.jetstream-cloud.org:8001/