#! /bin/bash
set -x

while getopts "c:i:p:f:r:b:k:s:d:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        i) RUNID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        f) FORWARD="$OPTARG"
        ;;
        r) REVERSE="$OPTARG"
        ;;
        b) BENSERVER="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        d) AWS_DEFAULT_REGION="$OPTARG"
        ;;
    esac
done

source $CONFIG

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# add ben blast job for each NT chunk
for ((chunk=0; chunk<$ECOPCRLINKS; chunk++)); do
    chunk=$(printf '%03d' $chunk)
    /etc/ben/ben add -s $BENSERVER -c "cd crux/crux/app/ecopcr; ./run_ecopcr.sh -c ~/crux/crux/vars/crux_vars.sh -p $PRIMER -F $FORWARD -R $REVERSE -l chunk_$chunk -b /tmp/ben-blast -k $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY -r $AWS_DEFAULT_REGION" $PRIMER-ecopcr-chunk_$chunk-$RUNID -o /etc/ben/output
    chunk=$(echo $chunk | sed 's/^0*//')  # Remove leading zeros
done