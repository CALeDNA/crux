#! /bin/bash

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

START=$(( $HOSTNAME * 2 + 2))
END=$((START + 2))
# # split nt chunks across all VMs
# SCALE=$(( ( $NTOTAL + ($NUMINSTANCES / 2) ) / $NUMINSTANCES )) # round to nearest whole number
# START=$(( $HOSTNAME * $SCALE ))
# END=$(( $START + $SCALE ))
# if (( $NTOTAL - ( $END - 1) < $SCALE ))
# then
#     END=${NTOTAL}
# fi

cat ${PRIMERS} | while read primer
do
    primer=$( echo ${primer} | cut -d ',' -f3 )
    mkdir -p ${SAMDIR}/${primer}/
    touch ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa
    touch ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa.taxid
    for (( i=${START}; i<${END}; i++ ))
    do
        chunk=$(printf '%02d' "$i")
        # download one bam file at a time
        echo "wget -q -c --tries=0 -P ${SAMDIR}/${primer} https://data.cyverse.org/dav-anon/iplant/home/shared/eDNA_Explorer/bwa/bwa-output/${RUNID}/${primer}-nt${chunk}.fasta.bam"
        wget -q -c --tries=0 -P ${SAMDIR}/${primer} https://data.cyverse.org/dav-anon/iplant/home/shared/eDNA_Explorer/bwa/bwa-output/${RUNID}/${primer}-nt${chunk}.fasta.bam
        # convert to sam
        samtools view -o ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.bam
        # remove bam
        rm ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.bam
        # get largest seq per nt accesion id
        python get-largest.py --primer ${primer} --output ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa --sam ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam --nucltaxid nucl_gb.accession2taxid --log logs.txt
        # remove sam
        rm ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam
    done

    # upload to cyverse
    gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/
    gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/${primer}
    gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/fa-taxid/logs/${RUNID}
    
    gocmd -c ${CYVERSE} put ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/${primer}/chunk${HOSTNAME}.fa
    gocmd -c ${CYVERSE} put ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/${primer}/chunk${HOSTNAME}.fa.taxid
    gocmd -c ${CYVERSE} put ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/${primer}/chunk${HOSTNAME}.tax.tsv
    gocmd -c ${CYVERSE} put logs.txt /iplant/home/shared/eDNA_Explorer/fa-taxid/logs/${RUNID}/logs_${HOSTNAME}.fa
done
