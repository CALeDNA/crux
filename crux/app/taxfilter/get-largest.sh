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

# download taxdump and taxid2taxonpath script
wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
mkdir taxdump
tar -xf taxdump.tar.gz -C taxdump
rm taxdump.tar.gz
git clone https://github.com/CALeDNA/taxid2taxonpath.git

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
        # get taxid
        python3 create_taxa.py --input ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk} --output ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}_tmp --log logs
        mv ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}_tmp ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}
        # create taxa
        python3 taxid2taxonpath/taxid2taxonpath.py -d taxdump/nodes.dmp -m taxdump/names.dmp -e taxdump/merged.dmp -l taxdump/delnodes.dmp -i ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}_tmp.taxid -o ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}.tax.tsv -c 2 -r 1
        # clean blast
        ./remove_uncultured.pl ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}.tax.tsv ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk} 
        mv ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}tmp ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}
        # remove gaps
        sed -i 's/-//g' ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}
        # get largest seq per nt accession id
        python3 get-largest.py --output ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa --input ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk} --nucltaxid nucl_gb.accession2taxid --log logs.txt
        # remove orig fasta file and temp tax
        rm ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}
        rm ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}.tax.tsv ${SAMDIR}/${primer}/${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta_${chunk}_taxonomy2.txt
    done

    # remove ambiguous bp
    removeAmbiguousfromFa.pl ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa > ${SAMDIR}/${primer}/chunk${HOSTNAME}_ambiguousremoved.fa
    # upload to js2 bucket
    aws s3 cp ${SAMDIR}/${primer}/chunk${HOSTNAME}_ambiguousremoved.fa s3://ednaexplorer/crux/${RUNID}/fa-taxid/${primer}/chunk${HOSTNAME}.fa --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 cp ${SAMDIR}/${primer}/chunk${HOSTNAME}.fa.taxid s3://ednaexplorer/crux/${RUNID}/fa-taxid/${primer}/chunk${HOSTNAME}.fa.taxid --endpoint-url https://js2.jetstream-cloud.org:8001/
done
aws s3 cp logs.txt s3://ednaexplorer/crux/${RUNID}/logs/fa-taxid_chunk${HOSTNAME}.txt --endpoint-url https://js2.jetstream-cloud.org:8001/
