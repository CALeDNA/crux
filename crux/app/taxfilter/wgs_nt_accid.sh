#! /bin/bash

set -x

CYVERSE_BASE="/iplant/home/shared/eDNA_Explorer/crux"
RUNID="2022-11-15"
primer="12S_MiFish_U_30_1000"
OUTPUT="out"

START=0
END=81
SAMDIR="bwa-mem"
for (( i=${START}; i<${END}; i++ ))
do
    chunk=$(printf '%02d' "$i")
    wget -q -c --tries=0 -P ${SAMDIR}/${primer} https://data.cyverse.org/dav-anon${CYVERSE_BASE}/${RUNID}/bwa-mem/${primer}-nt${chunk}.fasta.bam
    samtools view -o ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.bam
    # remove bam
    rm ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.bam
    # get WGS and NT columns
    cut ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam -f1 > out.f1
    cut ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam -f3 > out.f3
    # remove trailing numbers from WGS accid
    sed -i ':a;s/[0-9]//3;ta' out.f1
    # combine both columns
    paste out.f1 out.f3 >> ${OUTPUT}
    rm out.f1 out.f3
    # remove sam
    rm ${SAMDIR}/${primer}/${primer}-nt${chunk}.fasta.sam
done