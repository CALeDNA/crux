#!/bin/bash

set -x

CONFIG=""
VARS="/vars"
while getopts "c:h:v:p:f:r:l:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        v) VARS="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        f) FORWARD="$OPTARG"
        ;;
        r) REVERSE="$OPTARG"
        ;;
        l) LINKS="$OPTARG" # chunk file name
        ;;
    esac
done

cp ${VARS}/* .

source ${CONFIG}

OUTPUT="$PRIMER-$LINKS/OUTPUT"
mkdir $PRIMER-$LINKS
mkdir $OUTPUT

# download link files
aws s3 cp s3://ednaexplorer/CruxV2/ecopcr_links/$LINKS $PRIMER-$LINKS/$LINKS --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# run obi_ecopcr.sh on every URL in $PRIMER-$LINKS/$LINKS
parallel -I% --tag --max-args 1 -P ${THREADS} ./obi_ecopcr.sh -l % -p $PRIMER -f $FORWARD -r $REVERSE -d $PRIMER-$LINKS -b % -e $ERROR -c $CONFIG ::: $PRIMER-$LINKS/$LINKS

# combine primer fasta files into one
# PRIMERNAME=$( echo ${primer} | cut -d ',' -f3 )
find $OUTPUT/ -type f -name "*$PRIMER.fasta" | xargs -I{} cat {} >> $PRIMER-$LINKS.fasta

# upload combined fasta file
aws s3 cp $PRIMER-$LINKS.fasta s3://ednaexplorer/CruxV2/$RUNID/ecopcr/$PRIMER/$LINKS.fasta --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
# gocmd -c ${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/ecopcr/${PRIMERNAME}
# for i in {1..5}; do gocmd put -c ${CYVERSE} ${PRIMERNAME}_${HOSTNAME}.fasta ${CYVERSE_BASE}/${RUNID}/ecopcr/${PRIMERNAME}/chunk${HOSTNAME}.fasta && echo "Successful gocmd upload" && break || sleep 15; done
rm ${PRIMERNAME}_${HOSTNAME}.fasta

# cleanup
rm ${OUTPUT}/*
rm -r taxdump
rm logs
