#! /bin/bash

set -x
set -o allexport


while getopts "c:j:i:p:n:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        j) JOB="$OPTARG" # folder of this run
        ;;
        i) RUNID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        n) NTCHUNK="$OPTARG" # nt chunk number
        ;;
    esac
done

source ${CONFIG}

cd /mnt

# delete $JOB in case it exists locally from unfinished run
rm -rf $JOB 2>/dev/null

mkdir ${JOB}

# download ecopcr fasta and combine them
aws s3 sync s3://ednaexplorer/crux/$RUNID/ecopcr/$PRIMER ./$JOB/ecopcr --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

for f in $JOB/ecopcr/*
do
    touch $JOB/ecopcr/$PRIMER.fasta
    cat $f >> $JOB/ecopcr/$PRIMER.fasta
done

# download missing nt files
if [ ! -d "nt-missing-files" ] ; then
    aws s3 cp s3://ednaexplorer/crux/nt-missing-files.tar.gz . --endpoint-url https://js2.jetstream-cloud.org:8001/
    tar --skip-old-files -xf nt-missing-files.tar.gz
    rm nt-missing-files.tar.gz
fi

#blast input output files
output=$PRIMER-blast.fasta
input=$PRIMER.fasta

# check if blast already ran this (primer,nt) pair
not_exists=$(aws s3api head-object --bucket ednaexplorer --key crux/${RUNID}/fa-taxid/$PRIMER/${PRIMER}_${NTCHUNK}.fasta --endpoint-url https://js2.jetstream-cloud.org:8001/ >/dev/null 2>1; echo $?)
if [ $not_exists == 255 ];
then
    # file does not exist on aws
    # download nt file
    wget -q --retry-connrefused --timeout=300 --tries=inf --continue -P $JOB/nt$NTCHUNK ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt.$NTCHUNK.tar.gz
    tar -xf $JOB/nt$NTCHUNK/nt.$NTCHUNK.tar.gz -C $JOB/nt$NTCHUNK
    cp nt-missing-files/* $JOB/nt$NTCHUNK/
    sed -i "s/^DBLIST.*/DBLIST nt.$NTCHUNK /" $JOB/nt$NTCHUNK/nt.nal

    blastdbcmd -entry all -db $JOB/nt$NTCHUNK/nt -out $JOB/nt$NTCHUNK.fasta
    # break ecopcr fasta into small chunks
    awk -v job="$JOB" -v primer="$PRIMER" '/^>/ && ++splitCount % 100000 == 1 { close(file); file = sprintf("%s/ecopcr/%s_%d.split", job, primer, splitCount) } { print > file }' $JOB/ecopcr/$input
    # run blast in small chunks
    find "$JOB/ecopcr/" -name "$PRIMER_*.split" -print0 | parallel -0 -P $BLAST_THREADS "time blastn -query {} -out $JOB/{%}_${output}_$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt '6 saccver staxid sseq' -num_threads 1 -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND | \ 
    if [ -s $JOB/{%}_${output}_$NTCHUNK ]; then ./taxfilter.sh -f {%}_${output}_$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB; cat $JOB/$FILTER/{%}_${output}_$NTCHUNK >> $JOB/$PRIMER.fasta; rm $JOB/$FILTER/{%}_${output}_$NTCHUNK $JOB/{%}_${output}_$NTCHUNK"
else
    # file exists. checking if empty"
    length=$(aws s3api head-object --bucket ednaexplorer --key crux/${RUNID}/fa-taxid/$PRIMER/$PRIMER-blast.fasta_$NTCHUNK --endpoint-url https://js2.jetstream-cloud.org:8001/ | jq ".ContentLength")
    if (( $length > 0 )); 
    then
            echo "skipping $PRIMER-blast.fasta_$NTCHUNK"
            # free up storage for new jobs
            rm -rf $JOB
            exit 1
    else
        # empty file exists. rerun blast just in case
        # delete $JOB in case it exists locally from unfinished run
        rm -rf $JOB
        mkdir $JOB
        # download nt file
        wget -q --retry-connrefused --timeout=300 --tries=inf --continue -P $JOB/nt$NTCHUNK ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt.$NTCHUNK.tar.gz
        tar -xf $JOB/nt$NTCHUNK/nt.$NTCHUNK.tar.gz -C $JOB/nt$NTCHUNK
        sed -i "s/^DBLIST.*/DBLIST nt.$NTCHUNK /" $JOB/nt$NTCHUNK/nt.nal

        blastdbcmd -entry all -db $JOB/nt$NTCHUNK/nt -out $JOB/nt$chunk.fasta

        # break ecopcr fasta into small chunks
        awk -v job="$JOB" -v primer="$PRIMER" '/^>/ && ++splitCount % 100000 == 1 { close(file); file = sprintf("%s/ecopcr/%s_%d.split", job, primer, splitCount) } { print > file }' $JOB/ecopcr/$input
        # run blast in small chunks
        find "$JOB/ecopcr/" -name "$PRIMER_*.split" -print0 | parallel -0 -P $BLAST_THREADS "time blastn -query {} -out $JOB/{%}_${output}_$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt '6 saccver staxid sseq' -num_threads 1 -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND | \ 
        if [ -s $JOB/{%}_${output}_$NTCHUNK ]; then ./taxfilter.sh -f {%}_${output}_$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB; cat $JOB/$FILTER/{%}_${output}_$NTCHUNK >> $JOB/$PRIMER.fasta; rm $JOB/$FILTER/{%}_${output}_$NTCHUNK $JOB/{%}_${output}_$NTCHUNK"
    fi
fi

# rerun choose longest script on concat fasta
python3 get-largest.py --input $JOB/$PRIMER.fasta --output $JOB/${PRIMER}_${NTCHUNK}.fasta --log $JOB/logs
# upload to js2
aws s3 cp $JOB/${PRIMER}_${NTCHUNK}.fasta s3://ednaexplorer/crux/$RUNID/fa-taxid/$PRIMER/${PRIMER}_${NTCHUNK}.fasta --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
# aws s3 cp $JOB/$FILTER/${FASTA}.tax.tsv s3://ednaexplorer/crux/$RUNID/fa-taxid/$PRIMER/$FASTA.tax.tsv --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
aws s3 cp $JOB/logs s3://ednaexplorer/crux/$RUNID/logs/blast_${PRIMER}_${NTCHUNK}.txt --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress

# free up storage for new jobs
rm -rf $JOB