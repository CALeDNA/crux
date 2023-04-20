#! /bin/bash

while getopts "d:t:f:i:k:s:r:" opt; do
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
    esac
done

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}


primer=$(echo $FOLDER | cut -d"-" -f1)
# download master taxa and local fasta
aws s3 cp s3://ednaexplorer/crux/$RUNID/fa-taxid/$primer.tax.tsv . --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp s3://ednaexplorer/tronko/$RUNID/$FOLDER/$FASTA . --endpoint-url https://js2.jetstream-cloud.org:8001/


skip="FALSE"
while read line; do
    # loop through local fasta, get accid, and search in master taxa
    if [[ "$line" == ">"* ]]
    then
        accid="${line:1}"
        taxline=$(grep "$accid" $primer.tax.tsv)
        echo $taxline >> $TAXA
        sed 's/ /\t/' $TAXA > tmp && mv tmp $TAXA # grep converts tabs to space. Converting space back to tabs
    fi
done < $FASTA # master tax.tsv

aws s3 cp $TAXA s3://ednaexplorer/tronko/$RUNID/$FOLDER/$TAXA --endpoint-url https://js2.jetstream-cloud.org:8001/
