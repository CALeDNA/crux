#! /bin/bash

set -x

BLASTDIR="blast-output"
while getopts "f:p:c:i:j:k:s:r:" opt; do
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
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
    esac
done

# activate conda env
export PATH="/usr/local/miniconda/bin:$PATH";
source ${CONFIG}

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# download taxdump and taxid2taxonpath script
if [ ! -d "taxdump" ] ; then
    wget -nc -r -l inf --no-remove-listing ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
    mkdir -P taxdump
    tar -xf taxdump.tar.gz -C taxdump
    rm taxdump.tar.gz
fi

if [ ! -d "taxid2taxonpath" ] ; then
    git clone https://github.com/CALeDNA/taxid2taxonpath.git taxid2taxonpath
fi

# aws s3 cp s3://ednaexplorer/crux/$RUNID/blast/$FASTA $JOB/$BLASTDIR --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
# get taxid
python3 create_taxa.py --input $JOB/$FASTA --output $JOB/$BLASTDIR/${FASTA}_tmp --log logs
mv $JOB/$BLASTDIR/${FASTA}_tmp $JOB/$BLASTDIR/${FASTA}
# create taxa
python3 taxid2taxonpath/taxid2taxonpath.py -d taxdump/nodes.dmp -m taxdump/names.dmp -e taxdump/merged.dmp -l taxdump/delnodes.dmp -i $JOB/$BLASTDIR/${FASTA}_tmp.taxid -o $JOB/$BLASTDIR/$FASTA.tax.tsv -c 2 -r 1
# clean blast
./remove_uncultured.pl $JOB/$BLASTDIR/${FASTA}.tax.tsv $JOB/$BLASTDIR/${FASTA} 
# mv $JOB/$BLASTDIR/${FASTA}_tmp $JOB/$BLASTDIR/${FASTA}
# remove gaps
sed -i 's/-//g' $JOB/$BLASTDIR/${FASTA}_tmp
# get largest seq per nt accession id
python3 get-largest.py --output $JOB/$BLASTDIR/${FASTA} --input $JOB/$BLASTDIR/${FASTA}_tmp --log logs.txt
# mv $JOB/$BLASTDIR/${FASTA}_tmp $JOB/$BLASTDIR/${FASTA}


# # remove orig fasta file and temp tax
# rm ${BLASTDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}*

# upload to js2 bucket
aws s3 cp $JOB/$BLASTDIR/${FASTA} s3://ednaexplorer/crux/$RUNID/fa-taxid/$PRIMER/$FASTA --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
aws s3 cp $JOB/$BLASTDIR/${FASTA}.taxid s3://ednaexplorer/crux/$RUNID/fa-taxid/$PRIMER/$FASTA.taxid --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
aws s3 cp logs.txt s3://ednaexplorer/crux/$RUNID/logs/fa-taxid_$FASTA.txt --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress