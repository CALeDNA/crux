#! /bin/bash

set -x

NTDB="nt"
mkdir ${NTDB}

START=0
END=71
# run blastdbcmd and blastn and delete nt
for (( i=${START}; i<${END}; i++ ))
do
    chunk=$(printf '%02d' "$i")
    wget -q -c --tries=0 -P ${NTDB} https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/nt/nt.${chunk}.tar.gz
    tar -xf ${NTDB}/nt.${chunk}.tar.gz -C ${NTDB}
    sed -i "s/^DBLIST.*/DBLIST nt.${chunk} /" ${NTDB}/nt.nal
    blastdbcmd -entry all -db ${NTDB}/nt -out nt${chunk}.fasta

    blastn -query 12S_MiFish_U_30_1000.fasta -out 12S_MiFish_U_30_1000_${chunk}.txt -db ${NTDB}/nt -outfmt "6 saccver staxid sseq"
    blastn -query 12S_MiFish_U_50_800.fasta -out 12S_MiFish_U_50_800_${chunk}.txt -db ${NTDB}/nt -outfmt "6 saccver staxid sseq"

    cat 12S_MiFish_U_30_1000_${chunk}.txt | sed "s/-//g" | awk 'BEGIN { FS="\t"; } {print ">"$1"\n"$3}' >> 12S_MiFish_U_30_1000_blast.fasta
    cat 12S_MiFish_U_50_800_${chunk}.txt | sed "s/-//g" | awk 'BEGIN { FS="\t"; } {print ">"$1"\n"$3}' >> 12S_MiFish_U_50_800_blast.fasta

    rm ${NTDB}/nt.${chunk}.* # remove nt db
    rm nt${chunk}.fasta 12S_MiFish_U_30_1000_${chunk}.txt 12S_MiFish_U_50_800_${chunk}.txt # remove nt.fasta and tmp files
done
