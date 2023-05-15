#!/bin/bash
set -x
set -o allexport

PARTITION_NUMBER=0
while getopts "i:p:k:s:r:b:" opt; do
    case $opt in
        i) RUNID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
        b) PARTITION_NUMBER="$OPTARG"
        ;;
    esac
done

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}
export PATH=~/bin:$PATH

mkdir ${PRIMER}
# create merged newick folder
./merge_newick.sh -d ${PRIMER} -p ${PRIMER} -i ${RUNID} -k ${AWS_ACCESS_KEY_ID} -s ${AWS_SECRET_ACCESS_KEY} -r ${AWS_DEFAULT_REGION}

# merged newick
newick=~/${PRIMER}/merged_${PRIMER}
outdir=~/${PRIMER}/tronko_${PRIMER}
mkdir ${outdir}

partitions=$(ls ${newick}/*txt | wc -l)


if (( $partitions > 1 ))
then
    time ./bin/tronko-build -y -e ${newick} -n ${partitions} -d ${outdir} -b $PARTITION_NUMBER -s
else
    time ./bin/tronko-build -l -t "${newick}/RAxML_bestTree.0.reroot" -m "${newick}/0_MSA.fasta" -x "${newick}/0_taxonomy.txt" -d ${outdir}
fi