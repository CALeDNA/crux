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
mkdir ${JOB}

# download all ecopcr fasta files and combine them. 
aws s3 sync s3://ednaexplorer/crux/$RUNID/ecopcr ./ecopcr --endpoint-url https://js2.jetstream-cloud.org:8001/
# download ecopcr fasta and combine them
aws s3 sync s3://ednaexplorer/crux/$RUNID/ecopcr/$PRIMER ./$JOB/ecopcr --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

for d in $JOB/ecopcr/*
do
    # saves a master fasta per primer in ~/ecopcr
    cat ${d}*.fasta > "${d%/}".fasta
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
not_exists=$(aws s3api head-object --bucket ednaexplorer --key crux/${RUNID}/fa-taxid/$PRIMER/$PRIMER-blast.fasta_$NTCHUNK --endpoint-url https://js2.jetstream-cloud.org:8001/ >/dev/null 2>1; echo $?)
if [ $not_exists == 255 ];
then
    # file does not exist on aws
    # delete $JOB in case it exists locally from unfinished run
    rm -rf $JOB
    # download nt file
    wget -q --retry-connrefused --timeout=300 --tries=inf --continue -P $JOB/nt$NTCHUNK ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt.$NTCHUNK.tar.gz
    tar -xf $JOB/nt$NTCHUNK/nt.$NTCHUNK.tar.gz -C $JOB/nt$NTCHUNK
    cp nt-missing-files/* $JOB/nt$NTCHUNK/
    sed -i "s/^DBLIST.*/DBLIST nt.$NTCHUNK /" $JOB/nt$NTCHUNK/nt.nal

    blastdbcmd -entry all -db $JOB/nt$NTCHUNK/nt -out $JOB/nt$NTCHUNK.fasta
    # run blast in small chunks
    parallel --block 100k --recstart '>' -a ecopcr/$input -P $BLAST_THREADS "time blastn -query <(echo '{}') -out $JOB/{%}_${output}_$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt '6 saccver staxid sseq' -num_threads 1 -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND | \
    if [ -s $JOB/{%}_${output}_$NTCHUNK ]; then ./taxfilter.sh -f {%}_${output}_$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB; cat $JOB/$FILTER/${FASTA} >> $JOB/$PRIMER.fasta; fi"
    # # run blast
    # time blastn -query ecopcr/$input -out $JOB/${output}_$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt "6 saccver staxid sseq" -num_threads $BLAST_THREADS -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND
    # # clean blast output for tronko
    # ./taxfilter.sh -f ${output}_$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB
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
        # run blast in small chunks
        parallel --block 100k --recstart '>' -a ecopcr/$input -P $BLAST_THREADS "time blastn -query <(echo '{}') -out $JOB/{%}_${output}_$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt '6 saccver staxid sseq' -num_threads 1 -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND | \
        if [ -s $JOB/{%}_${output}_$NTCHUNK ]; then ./taxfilter.sh -f {%}_${output}_$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB; cat $JOB/$FILTER/${FASTA} >> $JOB/$PRIMER.fasta; fi"
        # # run blast
        # time blastn -query ecopcr/$input -out $JOB/${output}_$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt "6 saccver staxid sseq" -num_threads $BLAST_THREADS -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND
        # # clean blast output for tronko
        # ./taxfilter.sh -f ${output}_$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB
        # # output files uploaded in taxfilter script
    fi
fi

# rerurn taxfilter on master fasta
./taxfilter.sh -f $JOB/$PRIMER.fasta -p $PRIMER -c $CONFIG -i $RUNID -j $JOB
# upload to js2
aws s3 cp $JOB/$FILTER/${FASTA} s3://ednaexplorer/crux/$RUNID/fa-taxid/$PRIMER/$FASTA --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
aws s3 cp $JOB/$FILTER/${FASTA}.tax.tsv s3://ednaexplorer/crux/$RUNID/fa-taxid/$PRIMER/$FASTA.tax.tsv --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress
aws s3 cp $JOB/logs s3://ednaexplorer/crux/$RUNID/logs/fa-taxid_$FASTA.txt --endpoint-url https://js2.jetstream-cloud.org:8001/ --no-progress

# free up storage for new jobs
rm -rf $JOB