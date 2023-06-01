#! /bin/bash

set -x

while getopts "f:p:c:i:j:" opt; do
    case $opt in
        f) FASTA="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        i) RUNID="$OPTARG"
        ;;
        j) JOB="$OPTARG"
        ;;
    esac
done

source ${CONFIG}

# download taxdump and taxid2taxonpath script
if [ ! -d "taxdump" ] ; then
    wget -nc ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
    mkdir -p taxdump
    tar -xf taxdump.tar.gz -C taxdump
    rm taxdump.tar.gz
fi

if [ ! -d "taxid2taxonpath" ] ; then
    git clone https://github.com/CALeDNA/taxid2taxonpath.git taxid2taxonpath
fi

# aws s3 cp s3://ednaexplorer/crux/$RUNID/blast/$FASTA $JOB/$FILTER --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
mkdir -p $JOB/$FILTER
touch $JOB/$FILTER/${FASTA}_tmp
touch $JOB/logs
# creates accid taxid file
python3 create_taxa.py --input $JOB/$FASTA --output $JOB/$FILTER/${FASTA}.taxid --log $JOB/logs
mv $JOB/$FILTER/${FASTA}_tmp $JOB/$FILTER/$FASTA
# create taxa
python3 taxid2taxonpath/taxid2taxonpath.py -d taxdump/nodes.dmp -m taxdump/names.dmp -e taxdump/merged.dmp -l taxdump/delnodes.dmp -i $JOB/$FILTER/${FASTA}_tmp.taxid -o $JOB/$FILTER/$FASTA.tax.tsv -c 2 -r 1
# clean blast
./remove_uncultured.pl $JOB/$FILTER/$FASTA.tax.tsv $JOB/$FILTER/$FASTA

# remove gaps
sed -i 's/-//g' $JOB/$FILTER/${FASTA}_tmp
# get largest seq per nt accession id
rm $JOB/$FILTER/${FASTA}; touch $JOB/$FILTER/${FASTA}
python3 get-largest.py --input $JOB/$FILTER/${FASTA}_tmp --output $JOB/$FILTER/${FASTA} --log $JOB/logs
# mv $JOB/$FILTER/${FASTA}_tmp $JOB/$FILTER/${FASTA}


# # remove orig fasta file and temp tax
# rm ${FILTER}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}*

# upload to js2 bucket
# aws s3 cp $JOB/$FILTER/${FASTA} s3://ednaexplorer/crux/$RUNID/fa-taxid/$PRIMER/$FASTA --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
# aws s3 cp $JOB/$FILTER/${FASTA}.tax.tsv s3://ednaexplorer/crux/$RUNID/fa-taxid/$PRIMER/$FASTA.tax.tsv --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
# aws s3 cp $JOB/logs s3://ednaexplorer/crux/$RUNID/logs/fa-taxid_$FASTA.txt --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress