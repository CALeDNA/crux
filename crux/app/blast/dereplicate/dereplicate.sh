#! /bin/bash

# 1) download blast fastas
# 2) cat
# 3) run fix-fasta.py
# 4) run taxid2taxonpath
# 5) upload

set -o allexport

export AWS_MAX_ATTEMPTS=3

OUTPUT="/etc/ben/output"
while getopts "j:i:p:b:B:" opt; do
    case $opt in
        j) JOB="$OPTARG" # folder of this run
        ;;
        i) RUNID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        b) ACSERVER="$OPTARG"
        ;;
        B) NEWICKSERVER="$OPTARG"
        ;;
    esac
done


aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/blast/ ./$JOB/blast --exclude "*.tax.tsv" --exclude "logs/*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# download taxdump and taxid2taxonpath script
if [ ! -d "taxdump" ] ; then
    wget -q -nc ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
    mkdir -p taxdump
    tar -xf taxdump.tar.gz -C taxdump
    rm taxdump.tar.gz
fi

if [ ! -d "taxid2taxonpath" ] ; then
    git clone https://github.com/CALeDNA/taxid2taxonpath.git taxid2taxonpath
fi

cat $JOB/blast/* >> $JOB/$PRIMER.fa

python3 fix-fasta.py --input $JOB/$PRIMER.fa --output $JOB/$PRIMER.fasta --log logs

# remove ambiguous bp
removeAmbiguousfromFa.pl $JOB/$PRIMER.fasta > $JOB/${PRIMER}_ambiguousremoved
mv $JOB/${PRIMER}_ambiguousremoved $JOB/$PRIMER.fasta

python3 taxid2taxonpath/taxid2taxonpath.py -d taxdump/nodes.dmp -m taxdump/names.dmp -e taxdump/merged.dmp -l taxdump/delnodes.dmp -i $JOB/$PRIMER.fasta.taxid -o $JOB/$PRIMER.tax.tsv -c 2 -r 1


aws s3 cp $JOB/$PRIMER.fasta s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/dereplicated/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp $JOB/$PRIMER.tax.tsv s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/dereplicated/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp $JOB/$PRIMER.fasta.taxid s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/dereplicated/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# add ancestralclust ben job
ben add -s $ACSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/build:/mnt -v ~/crux/crux/vars:/vars -v /tmp:/tmp -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PRIMER-ac-$RUNID crux /mnt/ac.sh -p $PRIMER -j $PRIMER-ac -i $RUNID -b $ACSERVER -B $NEWICKSERVER -1" $PRIMER-ac-$RUNID -o $OUTPUT

# cleanup
sudo rm -r taxdump/ taxid2taxonpath/ $JOB logs