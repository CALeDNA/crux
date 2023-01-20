#! /bin/bash

set -x

SAMDIR="bwa-output"
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

source ${CONFIG}

# download nucl acc2taxid
wget -q -c --tries=0 ftp://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz
gunzip nucl_gb.accession2taxid.gz

HOSTNAME_=${HOSTNAME#0}

# split nt chunks evenly among all VMs
SCALE=$(( $NTOTAL / $NUMINSTANCES ))
REMAINDER=$(( $NTOTAL % $NUMINSTANCES + 1 ))
START=$(( $HOSTNAME_ * $SCALE ))
END=$(( $START + $SCALE ))
if (( $HOSTNAME != "00" ))
then
    if (( $HOSTNAME < $REMAINDER ))
    then
        START=$(( $HOSTNAME_ * $SCALE  + $HOSTNAME_ - 1 ))
        END=$(( $START + $SCALE + 1 ))
    else
        START=$(( $HOSTNAME_ * $SCALE + $REMAINDER - 1 ))
        END=$(( $START + $SCALE ))
    fi
fi

cat ${PRIMERS} | while read primer
do
    primer=$( echo ${primer} | cut -d ',' -f3 )
    mkdir -p ${SAMDIR}/${primer}/
    touch ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa
    touch ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa.taxid
    for (( i=${START}; i<${END}; i++ ))
    do
        chunk=$(printf '%02d' "$i")
        aws s3 cp s3://ednaexplorer/crux/${RUNID}/blast/ecopcr/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk} ${SAMDIR}/${primer}/ --endpoint-url https://js2.jetstream-cloud.org:8001/
        # get largest seq per nt accession id
        cat ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa >> ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}
        python get-largest.py --primer ${primer} --output ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa --input ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk} --nucltaxid nucl_gb.accession2taxid --log logs.txt
        # remove orig fasta file
        rm ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}
    done

    # upload to js2 bucket
    aws s3 cp ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa s3://ednaexplorer/crux/${RUNID}/fa-taxid/${primer}/chunk${HOSTNAME}.fa --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa.taxid s3://ednaexplorer/crux/${RUNID}/fa-taxid/${primer}/chunk${HOSTNAME}.fa.taxid --endpoint-url https://js2.jetstream-cloud.org:8001/
done
aws s3 cp logs.txt s3://ednaexplorer/crux/${RUNID}/logs/fa-taxid_chunk${HOSTNAME}.txt --endpoint-url https://js2.jetstream-cloud.org:8001/
