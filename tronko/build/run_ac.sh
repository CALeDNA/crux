#!/bin/bash
set -x
set -o allexport


max_length=20000
cutoff_length=25000
while getopts "d:t:f:j:i:k:s:r:" opt; do
    case $opt in
        d) FOLDER="$OPTARG" # folder of last run
        ;;
        t) TAXA="$OPTARG"
        ;;
        f) FASTA="$OPTARG"
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

mkdir ${JOB}

# step 1: download fasta and taxa file
aws s3 cp s3://ednaexplorer/tronko/${RUNID}/${FOLDER}/${TAXA} ${JOB}_taxonomy.txt --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp s3://ednaexplorer/tronko/${RUNID}/${FOLDER}/${FASTA} ${JOB}.fasta --endpoint-url https://js2.jetstream-cloud.org:8001/

fasta=${JOB}.fasta
taxa=${JOB}_taxonomy.txt
len=$(wc -l ${taxa} | cut -d ' ' -f1)

if (( $len > $cutoff_length ))
then
    # run ancestral clust
    bin_size=$(( ($len + $max_length - 1) / $max_length ))
    time ./bin/ancestralclust -i ${fasta} -t ${taxa} -d ${JOB} -f -u -r 1000 -b ${bin_size} -c 4 -p 75
else
    cp ${fasta} ${JOB}/0.fasta
    cp ${taxa} ${JOB}/0_taxonomy.txt
fi

# rm taxa and fasta files
rm ${taxa} ${fasta}

# upload ac output to aws
aws s3 sync ${JOB} s3://ednaexplorer/tronko/${RUNID}/${JOB} --endpoint-url https://js2.jetstream-cloud.org:8001/

# add ac jobs to queue
added_job="FALSE"
for file in ${JOB}/*taxonomy.txt
do
    len=$(wc -l ${file} | cut -d ' ' -f1)
    if (( $len > $cutoff_length ))
    then
        added_job="TRUE"
        folder=$( echo $file | rev | cut -d"/" -f2 | rev )
        taxa=$( basename $file )
        job=$( echo $taxa | sed 's/_[^_]*$//g')
        fasta="${job}.fasta"
        job=$(printf '%02d' "$job") # add leading zero
        job="${folder}${job}"
        # ben add -c "docker run -t -v $(pwd):/mnt --name ${job} -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} crux /mnt/run_ac.sh -d ${JOB} -t ${taxa} -f ${fasta} -j ${job} -i ${RUNID}" ${job} -f main -o output
        ./bin/ben add -c "./run_ac.sh -d ${folder} -t ${taxa} -f ${fasta} -k ${AWS_ACCESS_KEY_ID} -s ${AWS_SECRET_ACCESS_KEY} -r ${AWS_DEFAULT_REGION} -j ${job} -i ${RUNID}" ${job} -f main -o /home/ubuntu/ben/output/    
    fi
done

# if new output folder added a job, skip. otherwise start ac2newick
if [ "$added_job" = "FALSE" ]
then
    primer=$( echo $JOB | sed 's/-[^-]*$//g' ) # FOLDER="Cytb_Fish-ac00"
    suffix=$( echo $JOB | rev | cut -d'-' -f1 | rev | tr -dc '0-9' )
    job="${primer}-newick${suffix}"
    # ben add -c "docker run -t -v $(pwd):/mnt --name ${job} -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} crux /mnt/ac2newick.sh -d ${JOB} -j ${job} -i ${RUNID}" ${job} -f main -o output
    ./bin/ben add -c "./ac2newick.sh -d ${JOB} -k ${AWS_ACCESS_KEY_ID} -s ${AWS_SECRET_ACCESS_KEY} -r ${AWS_DEFAULT_REGION} -j ${job} -i ${RUNID}" ${job} -f main -o /home/ubuntu/ben/output/
fi

# delete local files
rm -r ${JOB}
# delete recursed file from bucket
aws s3 rm s3://ednaexplorer/tronko/${RUNID}/${FOLDER}/${TAXA} --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 rm s3://ednaexplorer/tronko/${RUNID}/${FOLDER}/${FASTA} --endpoint-url https://js2.jetstream-cloud.org:8001/

# check if parent bucket is newick ready
newick_ready="TRUE"
aws s3 sync s3://ednaexplorer/tronko/${RUNID}/${FOLDER}/ ${FOLDER} --endpoint-url https://js2.jetstream-cloud.org:8001/
for file in ${FOLDER}/*taxonomy.txt
do
    echo $file
    len=$(wc -l ${file} | cut -d ' ' -f1)
    if (( $len > $cutoff_length ))
    then
        newick_ready="FALSE"
        break
    fi
done

if [ "$newick_ready" = "TRUE" ]
then
    primer=$( echo $FOLDER | sed 's/-[^-]*$//g' ) # FOLDER="Cytb_Fish-ac00"
    suffix=$( echo $FOLDER | rev | cut -d'-' -f1 | rev | tr -dc '0-9' )
    if [ $( echo $FOLDER | rev | cut -d"-" -f1 | rev | tr -d [0-9]) != "ac" ]
    then
        echo "parent folder is root ancestralclust folder"
    else
        job="${primer}-newick${suffix}"
        # ben add -c "docker run -t -v $(pwd):/mnt --name ${job} -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} crux /mnt/ac2newick.sh -d ${FOLDER} -j ${job} -i ${RUNID}" ${job} -f main -o output
        ./bin/ben add -c "./ac2newick.sh -d ${FOLDER} -k ${AWS_ACCESS_KEY_ID} -s ${AWS_SECRET_ACCESS_KEY} -r ${AWS_DEFAULT_REGION} -j ${job} -i ${RUNID}" ${job} -f main -o /home/ubuntu/ben/output/
    fi
fi
