#!/bin/bash

set -x

CONFIG=""
while getopts "c:v:p:f:r:l:b:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        f) FORWARD="$OPTARG"
        ;;
        r) REVERSE="$OPTARG"
        ;;
        l) LINKS="$OPTARG" # chunk file name
        ;;
        b) BENSERVER="$OPTARG"
        ;;
    esac
done

cd /mnt
source ${CONFIG}

OUTPUT="$PRIMER-$LINKS/OUTPUT"
mkdir $PRIMER-$LINKS
mkdir $OUTPUT

# download taxdump
# wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
mkdir taxdump
wget -P taxdump https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump_archive/taxdmp_2023-06-01.zip
unzip -o taxdump/taxdmp_2023-06-01.zip -d taxdump; rm taxdump/taxdmp_2023-06-01.zip

# download link files
aws s3 cp s3://ednaexplorer/CruxV2/ecopcr_links/$LINKS $PRIMER-$LINKS/$LINKS --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# run obi_ecopcr.sh on every URL in $PRIMER-$LINKS/$LINKS
parallel -I% --tag --max-args 1 -P ${THREADS} ./obi_ecopcr.sh -l % -p $PRIMER -f $FORWARD -r $REVERSE -d $PRIMER-$LINKS -m 1000 -n 30 -b % -e $ERROR -c $CONFIG :::: $PRIMER-$LINKS/$LINKS

# combine primer fasta files into one
touch $PRIMER-$LINKS.fasta # in case $OUTPUT is empty
find $OUTPUT/ -type f -name "*$PRIMER.fasta" | xargs -I{} cat {} >> $PRIMER-$LINKS.fasta

# upload combined fasta file
aws s3 cp $PRIMER-$LINKS.fasta s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ecopcr/$LINKS.fasta --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

rm $PRIMER-$LINKS.fasta

# add ben blast job for each NT chunk
for ((nt=0; nt<$NTOTAL; nt++)); do
    nt=$(printf '%03d' $nt)
    ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/crux/app/blast:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PRIMER-blast-$LINKS-$nt-$RUNID crux /mnt/blast.sh -c /vars/crux_vars.sh -j $PRIMER-blast-$LINKS-$nt-$RUNID -i $RUNID -p $PRIMER -n $nt -e $LINKS.fasta" $PRIMER-blast-$LINKS-$nt-$RUNID -f main -o /etc/ben/output
    nt=$(echo $nt | sed 's/^0*//')  # Remove leading zeros
done

# cleanup
rm $PRIMER-$LINKS/*
rm -r taxdump
