#! /bin/bash

set -x
set -o allexport


while getopts "d:c:j:i:p:n:t:k:s:r:" opt; do
    case $opt in
        d) FOLDER="$OPTARG" # folder of last run
        ;;
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
        t) THREADS="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
    esac
done

# activate conda env
export PATH="/usr/local/miniconda/bin:$PATH";
source ${CONFIG}

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

mkdir ${JOB}

# download all ecopcr fasta files and combine them. 
aws s3 sync s3://ednaexplorer/crux/$RUNID/ecopcr ~/ecopcr --endpoint-url https://js2.jetstream-cloud.org:8001/

for d in ecopcr/*/
do
    # saves a master fasta per primer in ~/ecopcr
    cat ${d}*.fasta > "${d%/}".fasta
done

#blast input output files
output=$PRIMER-blast.fasta
input=$PRIMER.fasta

# check if blast already ran this (primer,nt) pair
not_exists=$(aws s3api head-object --bucket ednaexplorer --key crux/${RUNID}/blast/${output}_${chunk} --endpoint-url https://js2.jetstream-cloud.org:8001/ >/dev/null 2>1; echo $?)
if [ $not_exists == 255 ];
then
    # file does not exist
    # download nt file
    wget -q --retry-connrefused --timeout=300 --tries=inf --continue -P $JOB/nt$NTCHUNK ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt.$NTCHUNK.tar.gz
    tar -xf $JOB/nt$NTCHUNK/nt.$NTCHUNK.tar.gz -C $JOB/nt$NTCHUNK
    sed -i "s/^DBLIST.*/DBLIST nt.$NTCHUNK /" $JOB/nt$NTCHUNK/nt.nal

    blastdbcmd -entry all -db $JOB/nt$NTCHUNK/nt -out $JOB/nt$NTCHUNK.fasta
    # run blast
    time blastn -query $JOB/$input -out $JOB/${output}_$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt "6 saccver staxid sseq" -num_threads $THREADS -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND
    # clean blast output for tronko
    ./taxfilter.sh -f ${output}_$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB -k $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY -r $AWS_DEFAULT_REGION
else
    # file exists. checking if empty"
    length=$(aws s3api head-object --bucket ednaexplorer --key crux/${RUNID}/blast/${output}_$NTCHUNK --endpoint-url https://js2.jetstream-cloud.org:8001/ | jq ".ContentLength")
    if (( $length > 0 )); 
    then
            echo "skipping $file"
    else
        # empty file exists. rerun blast just in case
        # delete $JOB in case it exists
        rm -rf $JOB
        mkdir $JOB
        # download nt file
        wget -q --retry-connrefused --timeout=300 --tries=inf --continue -P $JOB/nt$NTCHUNK ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt.$NTCHUNK.tar.gz
        tar -xf $JOB/nt$NTCHUNK/nt.$NTCHUNK.tar.gz -C $JOB/nt$NTCHUNK
        sed -i "s/^DBLIST.*/DBLIST nt.$NTCHUNK /" $JOB/nt$NTCHUNK/nt.nal

        blastdbcmd -entry all -db $JOB/nt$NTCHUNK/nt -out $JOB/nt$chunk.fasta
        # run blast
        time blastn -query $JOB/$input -out $JOB/${output}_$NTCHUNK -db $JOB/nt$NTCHUNK/nt -outfmt "6 saccver staxid sseq" -num_threads $THREADS -evalue $eVALUE -perc_identity $PERC_IDENTITY -num_alignments $NUM_ALIGNMENTS -gapopen $GAP_OPEN -gapextend $GAP_EXTEND
        # clean blast output for tronko
        ./taxfilter.sh -f ${output}_$NTCHUNK -p $PRIMER -c $CONFIG -i $RUNID -j $JOB -k $AWS_ACCESS_KEY_ID -s $AWS_SECRET_ACCESS_KEY -r $AWS_DEFAULT_REGION
    fi
fi


# free up storage for new jobs
rm -rf $JOB