#!/bin/bash
set -x
set -o allexport


max_length=20000
cutoff_length=25000
FIRST="FALSE"
OUTPUT="/etc/ben/output"
while getopts "d:t:f:p:j:i:b:B:k:s:r:1?" opt; do
    case $opt in
        d) FOLDER="$OPTARG" # folder of last run
        ;;
        t) TAXA="$OPTARG"
        ;;
        f) FASTA="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        j) JOB="$OPTARG" # folder of this run
        ;;
        i) RUNID="$OPTARG"
        ;;
        b) ACSERVER="$OPTARG"
        ;;
        B) NEWICKSERVER="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
        1) FIRST="TRUE"
        ;;
    esac
done

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

currentdir=$(pwd)
cd ~/crux;
if [ "${FIRST}" = "TRUE" ]
then
    docker run --rm -t -v ~/crux/tronko/build:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PRIMER-ac-$RUNID crux /mnt/run_ac.sh -p $PRIMER -j $JOB -i $RUNID -b $ACSERVER -B $NEWICKSERVER -1
else
    docker run --rm -t -v ~/crux/tronko/build:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $JOB-$RUNID crux /mnt/run_ac.sh -d $FOLDER -t $TAXA -f $FASTA -p $PRIMER -j $JOB -i $RUNID -b $ACSERVER -B $NEWICKSERVER
fi
cd $currentdir

# add ac jobs to queue
added_job="FALSE"
for file in $JOB/dir/*taxonomy.txt
do
    len=$(wc -l $file | cut -d ' ' -f1)
    if (( $len > $cutoff_length ))
    then
        added_job="TRUE"
        folder=$( echo $file | rev | cut -d"/" -f3 | rev )
        taxa=$( basename $file )
        job=$( echo $taxa | sed 's/_[^_]*$//g')
        fasta="$job.fasta"
        job=$(printf '%02d' "$job") # add leading zero
        job="$folder$job" # -> ex: 12S_MiFish_U-ac-001203

        /etc/ben/ben add -s $ACSERVER -c "cd crux/tronko/build; ./ac.sh -d $folder -t $taxa -f $fasta -p $PRIMER -j $job -i $RUNID -b $ACSERVER -B $NEWICKSERVER -k $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY -r $AWS_DEFAULT_REGION " $job-$RUNID -f main -o $OUTPUT  
    fi
done

# if new output folder added a job, skip. otherwise start ac2newick
if [ "$added_job" = "FALSE" ]
then
    suffix=$( echo $JOB | rev | cut -d'-' -f1 | rev | tr -dc '0-9' )
    job="$PRIMER-newick$suffix"
    /etc/ben/ben add -s $NEWICKSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/build:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $job-$RUNID crux /mnt/ac2newick.sh -d $JOB -j $job -i $RUNID -p $PRIMER" $job-$RUNID -f main -o $OUTPUT
fi

# delete local files
rm -r $JOB/*

# delete recursed file from bucket
if [ "${FIRST}" != "TRUE" ]; then
    aws s3 rm s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER/$FASTA --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    aws s3 rm s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER/$TAXA --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
fi

# check if parent bucket is newick ready
newick_ready="TRUE"
if [ "${FIRST}" != "TRUE" ]; then
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ancestralclust/$FOLDER $JOB/$FOLDER --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    for file in $JOB/$FOLDER/*taxonomy.txt
    do
        echo $file
        len=$(wc -l ${file} | cut -d ' ' -f1)
        if (( $len > $cutoff_length ))
        then
            newick_ready="FALSE"
            break
        fi
    done
else
    newick_ready="FALSE"
fi

if [ "$newick_ready" = "TRUE" ]
then
    suffix=$( echo $FOLDER | rev | cut -d'-' -f1 | rev | tr -dc '0-9' )
    if [ "$FIRST" = "TRUE" ]
    then
        echo "parent folder is root ancestralclust folder"
    else
        job="$PRIMER-newick$suffix"
        /etc/ben/ben add -s $NEWICKSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/build:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $job-$RUNID crux /mnt/ac2newick.sh -d $FOLDER -j $job -i $RUNID -p $PRIMER" $job-$RUNID -f main -o $OUTPUT
    fi
fi
