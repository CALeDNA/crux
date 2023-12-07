#!/bin/bash


export AWS_MAX_ATTEMPTS=3

CONFIG=""
BENSERVER="/tmp/ben-blast"
while getopts "c:v:p:f:r:l:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        f) FORWARD="$OPTARG"
        ;;
        r) REVERSE="$OPTARG"
        ;;
        l) LINKS="$OPTARG" # chunk file name
        ;;
    esac
done

cd /mnt
source ${CONFIG}

OUTPUT="$PRIMER-$LINKS/OUTPUT"
mkdir $PRIMER-$LINKS
mkdir $OUTPUT

# download taxdump
# wget ftp://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump.tar.gz
mkdir taxdump
wget -P taxdump https://ftp.ncbi.nlm.nih.gov/pub/taxonomy/taxdump_archive/taxdmp_2023-06-01.zip
unzip -o taxdump/taxdmp_2023-06-01.zip -d taxdump; rm taxdump/taxdmp_2023-06-01.zip

# download link files
aws s3 cp s3://$BUCKET/CruxV2/ecopcr_links/$LINKS $PRIMER-$LINKS/$LINKS --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# run obi_ecopcr.sh on every URL in $PRIMER-$LINKS/$LINKS
parallel -I% --tag --max-args 1 -P ${THREADS} ./obi_ecopcr.sh -l % -p $PRIMER -f $FORWARD -r $REVERSE -d $PRIMER-$LINKS -m 1000 -n 30 -b % -e $ERROR :::: $PRIMER-$LINKS/$LINKS

# combine primer fasta files into one
touch $PRIMER-$LINKS.fasta # in case $OUTPUT is empty
find $OUTPUT/ -type f -name "*$PRIMER.fasta" | xargs -I{} cat {} >> $PRIMER-$LINKS.fasta

# split fasta into files of size ~10MB
max_size=$((10 * 1024 * 1024)) # 10 MB in bytes
current_size=0
file_count=0
output="${LINKS}$(printf "%03d" $file_count).fasta"
while IFS= read -r line
do
    if [[ $line == ">"* && $current_size -ge $max_size ]]; then
        # Start a new file if the current size exceeds the max_size
        ((file_count++))
        formatted_count=$(printf "%03d" $file_count)
        output="${LINKS}${formatted_count}.fasta"
        current_size=0
    fi
    # Write the line to the current output file
    echo "$line" >> "$output"
    # Update the current size (approximate, as it counts characters, not bytes)
    current_size=$((current_size + ${#line} + 1))
done < "$PRIMER-$LINKS.fasta"

# upload fasta files
aws s3 sync . s3://$BUCKET/CruxV2/$RUNID/$PRIMER/ecopcr/ --exclude "*" --include "${LINKS}*.fasta" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

rm $PRIMER-$LINKS.fasta

# add ben blast job for each NT chunk and ecopcr file
for file in ${LINKS}*.fasta; do
    if [[ -f "$file" ]]; then
        echo "Adding blast jobs for file: $file"
        newLink=$(basename $file)
        newLink=${newLink%.*}
        for ((nt=0; nt<$NTOTAL; nt++)); do
            nt=$(printf '%03d' $nt)
            ben add -s $BENSERVER -c "docker run --rm -t -v ~/crux/crux/app/blast:/mnt -v ~/crux/crux/vars:/vars -v /tmp:/tmp -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $PRIMER-blast-$newLink-$nt-$RUNID crux /mnt/blast.sh -c /vars/crux_vars.sh -j $PRIMER-blast-$newLink-$nt-$RUNID -i $RUNID -p $PRIMER -n $nt -e $newLink.fasta" $PRIMER-blast-$newLink-$nt-$RUNID -o /etc/ben/output
            nt=$(echo $nt | sed 's/^0*//')  # Remove leading zeros
        done        
    fi
done

# cleanup
rm -r $PRIMER-$LINKS
rm -r taxdump
