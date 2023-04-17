#! /bin/bash

set -x
set -o allexport


while getopts "c:o:k:s:r:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        o) OUTPUT="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
    esac
done

source $CONFIG

PRIMERS=$(cat $PRIMERS)

#loop through primers
#    add ben blast job. 1 job per nt chunk and primer pair
#    include runid in ben job name to differentiate in ben list.
for line in ${PRIMERS}
do
    for (( nt=0; nt<$NTOTAL; nt++ ))
    do
        nt_=$((10#$nt))
        nt_=$(printf '%02d' $nt_)
        primer=$( echo $line | cut -d ',' -f3 )
        job=$primer-$nt_-blast-$RUNID
        ben add -c "cd crux; docker run -t -v ~/crux/crux/app/blast:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $job crux /mnt/blast.sh -c "/vars/crux_vars.sh" -j $job -i $RUNID -p $primer -n $nt_" $job -o $OUTPUT
    done
done