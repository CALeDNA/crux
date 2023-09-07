#!/bin/bash
set -x
set -o allexport

PARTITION_NUMBER=0
while getopts "i:p:b:" opt; do
    case $opt in
        i) RUNID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        b) PARTITION_NUMBER="$OPTARG"
        ;;
    esac
done

cd /mnt

mkdir ${PRIMER}
# create merged newick folder
./merge_newick.sh -d ${PRIMER} -p ${PRIMER} -i ${RUNID}

# merged newick
newick=$(pwd)/${PRIMER}/merged_${PRIMER}
outdir=$(pwd)/${PRIMER}/tronko_${PRIMER}
mkdir ${outdir}

partitions=$(ls ${newick}/*txt | wc -l)

# sync down tronko output
aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $outdir --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


if (( $partitions > 1 ))
then
    time tronko-build -y -e ${newick} -n ${partitions} -d ${outdir} -b $PARTITION_NUMBER -s
else
    time tronko-build -l -t "${newick}/RAxML_bestTree.0.reroot" -m "${newick}/0_MSA.fasta" -x "${newick}/0_taxonomy.txt" -d ${outdir}
fi

# gzip
gzip $outdir/reference_tree.txt
# make fasta and taxa
cat $newick/*fasta >> $outdir/$PRIMER.fasta
cat $newick/*_taxonomy.txt >> $outdir/${PRIMER}_taxonomy.txt

# make bwa index
bwa index $outdir/$PRIMER.fasta

# upload
aws s3 sync $outdir s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# cleanup
rm -r $PRIMER