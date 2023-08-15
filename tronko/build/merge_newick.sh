#!/bin/bash
set -o xtrace

while getopts "d:p:i:" opt; do
    case $opt in
        d) FOLDER="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        i) RUNID="$OPTARG"
        ;;
    esac
done

# dl primer's newick folders
aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/newick $FOLDER --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# get list of newick folders per primer
folders=$(find ${FOLDER} -maxdepth 1 -mindepth 1 -type d -name "${PRIMER}*")

counter=0
outdir="${FOLDER}/merged_${PRIMER}"
mkdir $outdir

# combine newick folders
for folder in $folders
do
    for dir in ${folder}/*RAxML
    do
        prefix=$(basename $dir | xargs -I{} sh -c 'echo ${1%_RAxML}' -- {})
        # move and rename necessary files with that prefix to "merged_${FOLDER}"
        # and update counter
        nw_reroot $folder/${prefix}_RAxML/RAxML_bestTree.1 > $folder/RAxML_bestTree.${prefix}.reroot
        cp $folder/RAxML_bestTree.${prefix}.reroot ${outdir}/RAxML_bestTree.${counter}.reroot
        cp $folder/${prefix}_MSA.fasta ${outdir}/${counter}_MSA.fasta
        cp $folder/${prefix}_taxonomy.txt ${outdir}/${counter}_taxonomy.txt
        counter=$((counter+1))
    done
done

# upload cp to aws
aws s3 sync ${outdir} s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/newick/merged_$PRIMER --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
# rm orig newick folders
rm -r ${FOLDER}/${PRIMER}-newick*