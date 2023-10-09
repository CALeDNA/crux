#!/bin/bash
set -o allexport

export AWS_MAX_ATTEMPTS=3

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


fixNewLines() {
    local file=$1
    sed -i ':a; $!N; /^>/!s/\n\([^>]\)/\1/; ta; P; D' "$file" # fixes newlines
}

mkdir -p $JOB/newick

# download ancestralclust folder
aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER $JOB/$FOLDER/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

echo "running newick steps in $JOB/$FOLDER, saving in $JOB/newick"

find $JOB/$FOLDER -maxdepth 1 -type f -name '*fasta' | parallel -j2 '
    filepath={}
    i=$(basename "$filepath" .fasta) # 1, 2 etc
    # check if newick already ran on ${i}_MSA.fasta
    file_exists=$(aws s3api head-object --bucket ednaexplorer --key "CruxV2/$RUNID/$PRIMER/newick/$JOB/${i}_MSA.fasta" --endpoint-url https://js2.jetstream-cloud.org:8001/ 2>/dev/null && echo "true" || echo "false")
    if [ "$file_exists" == "false" ]; then
        famsa "$JOB/$FOLDER/${i}.fasta" "$JOB/newick/${i}_MSA.fasta" # converts to famsa
        fixNewLines "$JOB/newick/${i}_MSA.fasta"
        fasta2phyml.pl "$JOB/newick/${i}_MSA.fasta" # converts to phyml
        mkdir -p "$JOB/newick/${i}_RAxML"
        raxmlHPC-PTHREADS-SSE3 silent -m GTRGAMMA -w $(pwd)/$JOB/newick/${i}_RAxML -n 1 -p 1234 -T 4 -s $(pwd)/$JOB/newick/${i}_MSA.phymlAln # converts to raxml
        nw_reroot $JOB/newick/${i}_RAxML/RAxML_bestTree.1 > $JOB/newick/RAxML_bestTree.${i}.reroot # converts to newick
        cp $JOB/$FOLDER/${i}_taxonomy.txt $JOB/newick/${i}_taxonomy.txt # copy taxa file to output folder
        # upload output
        aws s3 sync $JOB/newick/ s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/newick/$JOB --exclude "*" --include "${i}_*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    fi
'

# cleanup
rm -r $JOB