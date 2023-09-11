#! /bin/bash

set -x

CONFIG=""
while getopts "c:v:p:F:R:l:b:k:s:r:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        F) FORWARD="$OPTARG"
        ;;
        R) REVERSE="$OPTARG"
        ;;
        l) LINKS="$OPTARG" # chunk file name
        ;;
        b) BENSERVER="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
    esac
done

source ${CONFIG}

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# docker run ecopcr.sh
docker run --rm -t -v ~/crux/crux/app/ecopcr:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PRIMER-ecopcr-$LINKS-$RUNID crux /mnt/ecopcr.sh -c /vars/crux_vars.sh -p $PRIMER -f $FORWARD -r $REVERSE -l $LINKS

# add ben blast job for each NT chunk
for ((nt=0; nt<$NTOTAL; nt++)); do
    nt=$(printf '%03d' $nt)
    ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/crux/app/blast:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PRIMER-blast-$LINKS-$nt-$RUNID crux /mnt/blast.sh -c /vars/crux_vars.sh -j $PRIMER-blast-$LINKS-$nt-$RUNID -i $RUNID -p $PRIMER -n $nt -e $LINKS.fasta" $PRIMER-blast-$LINKS-$nt-$RUNID -f main -o /etc/ben/output
    nt=$(echo $nt | sed 's/^0*//')  # Remove leading zeros
done