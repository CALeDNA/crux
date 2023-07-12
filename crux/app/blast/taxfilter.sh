#! /bin/bash

set -x

BLASTDIR="blast-output"
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

mkdir -p $JOB/$BLASTDIR
touch $JOB/$BLASTDIR/${FASTA}_tmp
touch $JOB/logs
# creates accid taxid file. --output=fasta & accidtaxid file={output fasta}.taxid
python3 create_taxa.py --input $JOB/$FASTA --output $JOB/$BLASTDIR/${FASTA}_tmp --log $JOB/logs
mv $JOB/$BLASTDIR/${FASTA}_tmp $JOB/$BLASTDIR/$FASTA
# create taxa
python3 taxid2taxonpath/taxid2taxonpath.py -d taxdump/nodes.dmp -m taxdump/names.dmp -e taxdump/merged.dmp -l taxdump/delnodes.dmp -i $JOB/$BLASTDIR/${FASTA}_tmp.taxid -o $JOB/$BLASTDIR/$FASTA.tax.tsv -c 2 -r 1
# clean blast
./remove_uncultured.pl $JOB/$BLASTDIR/$FASTA.tax.tsv $JOB/$BLASTDIR/$FASTA

# remove gaps
sed -i 's/-//g' $JOB/$BLASTDIR/${FASTA}_tmp
# get largest seq per nt accession id
rm $JOB/$BLASTDIR/${FASTA}; touch $JOB/$BLASTDIR/${FASTA}
python3 get-largest.py --input $JOB/$BLASTDIR/${FASTA}_tmp --output $JOB/$BLASTDIR/${FASTA} --log $JOB/logs

# upload to js2 bucket
aws s3 cp $JOB/$BLASTDIR/$FASTA s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/blast/$FASTA --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp $JOB/$BLASTDIR/$FASTA.tax.tsv s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/blast/$FASTA.tax.tsv --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp $JOB/logs s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/logs/$FASTA.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/