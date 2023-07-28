#!/bin/bash
set -x
set -o allexport

INPUT="." # folder containing {1..n}.fasta
OUTPUT="." # folder to output results

while getopts "d:j:i:p:" opt; do
    case $opt in
        d) FOLDER="$OPTARG" # ancestralclust folder
        ;;
        j) JOB="$OPTARG" # folder of this run
        ;;
        i) RUNID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
    esac
done

mkdir -p $JOB/newick

# download ancestralclust folder
aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER $JOB/$FOLDER/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

echo "running newick steps in $JOB/$FOLDER, saving in $JOB/newick"

for f in $(find $JOB/$FOLDER -maxdepth 1 -type f -name '*fasta')
do
    i=$(basename $f .fasta) # 1, 2 etc
    famsa "$JOB/$FOLDER/${i}.fasta" "$JOB/newick/${i}_MSA.fasta" # converts to famsa
    sed -i ':a; $!N; /^>/!s/\n\([^>]\)/\1/; ta; P; D' "$JOB/newick/${i}_MSA.fasta" # fixes newlines
    fasta2phyml.pl "$JOB/newick/${i}_MSA.fasta" # converts to phyml
    mkdir -p "$JOB/newick/${i}_RAxML"
    raxmlHPC-PTHREADS-SSE3 silent -m GTRGAMMA -w $(pwd)/$JOB/newick/${i}_RAxML -n 1 -p 1234 -T 4 -s $(pwd)/$JOB/newick/${i}_MSA.phymlAln # converts to raxml
    nw_reroot $JOB/newick/${i}_RAxML/RAxML_bestTree.1 > $JOB/newick/RAxML_bestTree.${i}.reroot # converts to newick
    cp $JOB/$FOLDER/${i}_taxonomy.txt $JOB/newick/${i}_taxonomy.txt # copy taxa file to output folder
done

# upload output
aws s3 sync $JOB/newick s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/newick/$JOB --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# cleanup
rm -r $JOB