#! /bin/bash

SAMDIR="bwa-output"
while getopts "c:h:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
    esac
done

source ${CONFIG}

# download nucl acc2taxid
wget ftp://ftp.ncbi.nih.gov/pub/taxonomy/accession2taxid/nucl_gb.accession2taxid.gz
gunzip nucl_gb.accession2taxid.gz


# split nt chunks across all VMs
SCALE=$(( ( $NTOTAL + ($NUMINSTANCES / 2) ) / $NUMINSTANCES )) # round to nearest whole number
START=$(( $HOSTNAME * $SCALE ))
END=$(( $START + $SCALE ))
if (( $NTOTAL - ( $END - 1) < $SCALE ))
then
    END=${NTOTAL}
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
        # download one bam file at a time
        wget -P ${SAMDIR}/${primer} https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/bwa-output/${primer}-nt${chunk}.fasta.bam
        # convert to sam
        samtools view -o ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.bam
        # remove bam
        rm ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.bam
        # get largest seq per nt accesion id
        python get-largest.py --primer ${primer} --output ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa --sam ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam --nucltaxid nucl_gb.accession2taxid --log logs.txt
        # remove bam and sam files
        rm ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam
    done

    # upload to cyverse
    gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/${primer}
    gocmd -c ${CYVERSE} mkdir /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/logs
    
    gocmd -c ${CYVERSE} put ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/${primer}/chunk${HOSTNAME}.fa
    gocmd -c ${CYVERSE} put logs.txt /iplant/home/shared/eDNA_Explorer/fa-taxid/${RUNID}/logs/logs_${HOSTNAME}.fa
done
