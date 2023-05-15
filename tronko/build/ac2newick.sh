#!/bin/bash
set -x
set -o allexport

INPUT="." # folder containing {1..n}.fasta
OUTPUT="." # folder to output results

while getopts "d:j:i:k:s:r:" opt; do
    case $opt in
        d) FOLDER="$OPTARG" # folder of last run
        ;;
        j) JOB="$OPTARG" # folder of this run
        ;;
        i) RUNID="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
    esac
done

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# download ancestralclust folder
aws s3 sync s3://ednaexplorer/tronko/${RUNID}/${FOLDER} ${FOLDER}/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

echo "converting fasta to tronko in $FOLDER, saving in $JOB"

mkdir -p $JOB

for f in $(find $FOLDER -maxdepth 1 -type f -name '*fasta')
do
    i=$(basename $f .fasta) # 1, 2 etc
    ./bin/famsa "$FOLDER/${i}.fasta" "${JOB}/${i}_MSA.fasta" # converts to famsa
    sed -i ':a; $!N; /^>/!s/\n\([^>]\)/\1/; ta; P; D' "${JOB}/${i}_MSA.fasta" # fixes newlines
    ./bin/fasta2phyml.pl "${JOB}/${i}_MSA.fasta" # converts to phyml
    mkdir -p "${JOB}/${i}_RAxML"
    ./bin/raxmlHPC-PTHREADS-SSE3 silent -m GTRGAMMA -w $(pwd)/"${JOB}/${i}_RAxML" -n 1 -p 1234 -T 4 -s "${JOB}/${i}_MSA.phymlAln" # converts to raxml
    ./miniconda/bin/nw_reroot "${JOB}/${i}_RAxML/RAxML_bestTree.1" > "${JOB}/RAxML_bestTree.${i}.reroot" # converts to newick
    cp ${FOLDER}/${i}_taxonomy.txt ${JOB}/${i}_taxonomy.txt # copy taxa file to output folder
done

# upload output
aws s3 sync ${JOB} s3://ednaexplorer/tronko/${RUNID}/${JOB} --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# delete local files
rm -r ${JOB} ${FOLDER}