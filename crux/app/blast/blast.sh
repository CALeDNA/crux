#! /bin/bash

set -x
set -o allexport

export AWS_MAX_ATTEMPTS=3
while getopts "c:j:i:p:n:e:" opt; do
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
        e) ECOPCRCHUNK="$OPTARG"
        ;;
    esac
done

source $CONFIG

cd /mnt

# delete $JOB in case it exists locally from unfinished run
rm -rf $JOB 2>/dev/null

mkdir $JOB

# download ecopcr fasta file
aws s3 cp s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/ecopcr/$ECOPCRCHUNK ./ecopcr/$ECOPCRCHUNK --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# download missing nt files
if [ ! -d "nt-missing-files" ] ; then
    aws s3 cp s3://ednaexplorer/CruxV2/nt-missing-files.tar.gz . --no-progress  --endpoint-url https://js2.jetstream-cloud.org:8001/
    tar --skip-old-files -xf nt-missing-files.tar.gz
    rm nt-missing-files.tar.gz
fi

#blast input output files
output=$PRIMER-blast-$ECOPCRCHUNK

# check if blast already ran this (primer,nt) pair
not_exists=$(aws s3api head-object --bucket ednaexplorer --key CruxV2/$RUNID/$PRIMER/blast/$output-$NTCHUNK --endpoint-url https://js2.jetstream-cloud.org:8001/ >/dev/null 2>1; echo $?)
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
    # run blast
    time blastn -query ./ecopcr/$ECOPCRCHUNK -out $JOB/$output-$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt "6 saccver staxid sseq" -num_threads $BLAST_THREADS -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND
    # run taxfilter if blastn output is not empty
    if [ -s $JOB/$output-$NTCHUNK ]; then
        # clean blast output for tronko
        ./taxfilter.sh -f $output-$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB
    else
        echo "Output file is empty. Skipping taxfilter.sh step."
    fi
else
    # file exists. checking if empty"
    length=$(aws s3api head-object --bucket ednaexplorer --key CruxV2/$RUNID/$PRIMER/blast/$output-$NTCHUNK --endpoint-url https://js2.jetstream-cloud.org:8001/ | jq ".ContentLength")
    if (( $length > 0 )); 
    then
            echo "skipping $output-$NTCHUNK"
    else
        # empty file exists. rerun blast just in case
        # download nt file
        wget -q --retry-connrefused --timeout=300 --tries=inf --continue -P $JOB/nt$NTCHUNK ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt.$NTCHUNK.tar.gz
        tar -xf $JOB/nt$NTCHUNK/nt.$NTCHUNK.tar.gz -C $JOB/nt$NTCHUNK
        cp nt-missing-files/* $JOB/nt$NTCHUNK/
        sed -i "s/^DBLIST.*/DBLIST nt.$NTCHUNK /" $JOB/nt$NTCHUNK/nt.nal

        blastdbcmd -entry all -db $JOB/nt$NTCHUNK/nt -out $JOB/nt$NTCHUNK.fasta
        # run blast
        time blastn -query ./ecopcr/$ECOPCRCHUNK -out $JOB/$output-$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt "6 saccver staxid sseq" -num_threads $BLAST_THREADS -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND
        # run taxfilter if blastn output is not empty
        if [ -s $JOB/$output-$NTCHUNK ]; then
            # clean blast output for tronko
            ./taxfilter.sh -f $output-$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB
        else
            echo "Output file is empty. Skipping taxfilter.sh step."
            ./taxfilter.sh -f $output-$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB -s
        fi
    fi
fi

# cleanup
rm -rf $JOB

#TODO: check if blast folder has (142*108) files
total=$((ECOPCRLINKS * NTOTAL))
actual=$(aws s3 ls s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/blast --recursive --endpoint-url https://js2.jetstream-cloud.org:8001/ | grep -v -e "CruxV2/$RUNID/$PRIMER/blast/logs" -e ".*tax.tsv" | wc -l)
if [ "$total" -eq "$actual" ]; then
    #start dereplicate step
    cd /mnt/dereplicate
    ./dereplicate.sh -j $PRIMER-dereplicate -i $RUNID -p $PRIMER -b /tmp/ben-ac -B /tmp/ben-newick
else
    echo "Blast still running in other machines for primer $PRIMER."
fi