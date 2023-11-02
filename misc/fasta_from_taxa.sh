#! /bin/bash

export AWS_MAX_ATTEMPTS=3

while getopts "d:t:f:i:k:s:r:b:" opt; do
    case $opt in
        d) FOLDER="$OPTARG" # folder of last run
        ;;
        t) TAXA="$OPTARG"
        ;;
        f) FASTA="$OPTARG"
        ;;
        i) RUNID="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
        b) BUCKET="$OPTARG"
        ;;
    esac
done

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}


primer=$(echo $FOLDER | cut -d"-" -f1)
# download master fasta and local taxa
aws s3 cp s3://$BUCKET/crux/$RUNID/fa-taxid/$primer.fa . --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp s3://$BUCKET/tronko/$RUNID/$FOLDER/$TAXA . --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


while read line; do
    # loop through local taxa and grep in master fasta
    accid=$(echo $line | cut -d" " -f1)
    accid=$(grep $accid $primer.fa)
    linenumber=$( grep -n $accid $primer.fa | cut -d":" -f1)
    linenumber=$(( linenumber + 1 ))
    seq=$(sed "${linenumber}q;d" $primer.fa)
    echo $accid >> $FASTA
    echo $seq >> $FASTA
done < $TAXA # local taxonomy

aws s3 cp $FASTA s3://$BUCKET/tronko/$RUNID/$FOLDER/$FASTA --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
