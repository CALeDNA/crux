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
    /etc/ben/ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/crux/app/ecopcr:/mnt -v ~/crux/crux/vars:/vars -v /etc/ben:/etc/ben -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PRIMER-ecopcr-chunk_$chunk-$RUNID crux /mnt/ecopcr.sh -c /vars/crux_vars.sh -p $PRIMER -f $FORWARD -r $REVERSE -l chunk_$chunk -b /tmp/ben-blast" $PRIMER-ecopcr-chunk_$chunk-$RUNID -o /etc/ben/output
    chunk=$(echo $chunk | sed 's/^0*//')  # Remove leading zeros
done