#!/bin/bash
set -o allexport

export AWS_MAX_ATTEMPTS=3

PARTITION_NUMBER=0
while getopts "i:p:" opt; do
    case $opt in
        i) RUNID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
    esac
done

source /vars/crux_vars.sh

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
aws s3 sync s3://$BUCKET/CruxV2/$RUNID/$PRIMER/tronko $outdir --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# Calculate b (PARTITION_NUMBER)
for i in {999..999999}; do
    if ! [[ -e "partition${i}.fasta" && -e "partition${i}_MSA.fasta" ]]; then
        echo "The first number without both fasta files is: ${i}"
        PARTITION_NUMBER=$i
        break
    fi
done

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
aws s3 sync $outdir s3://$BUCKET/CruxV2/$RUNID/$PRIMER/tronko --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# cleanup
rm -r $PRIMER