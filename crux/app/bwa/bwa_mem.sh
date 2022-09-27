#! /bin/bash

OUTPUT=""
INDEX=""
RUNID=""
THREADS=""
URLS="chunks.txt"
CONFIG=""

while getopts "o:i:r:h:t:c:" opt; do
    case $opt in
        o) OUTPUT="$OPTARG"
        ;;
        i) INDEX="$OPTARG" 
        ;;
        r) RUNID="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        t) THREADS="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${OUTPUT} && ! -z ${INDEX} && ! -z ${RUNID} && ! -z ${THREADS} && ! -z ${CONFIG} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -n, -o and -i"
  echo ""
  exit
fi

source ${CONFIG}

ECOPCR=$(find ecopcr/${RUNID}/ -maxdepth 1 -type f)
HOSTNAME=${HOSTNAME#0}

# split nt chunks evenly among all VMs
SCALE=$(( $NTOTAL / $NUMINSTANCES ))
REMAINDER=$(( $NTOTAL % $NUMINSTANCES + 1 ))
START=$(( $HOSTNAME * $SCALE ))
END=$(( $START + $SCALE ))
if (( $HOSTNAME != "00" ))
then
    if (( $HOSTNAME < $REMAINDER ))
    then
        START=$(( $HOSTNAME * $SCALE  + $HOSTNAME - 1 ))
        END=$(( $START + $SCALE + 1 ))
    else
        START=$(( $HOSTNAME * $SCALE + $REMAINDER - 1 ))
        END=$(( $START + $SCALE ))
    fi
fi

for (( c=${START}; c<${END}; c++ ))
do
    chunk=$(printf '%02d' "$c")
    echo "https://data.cyverse.org/dav-anon/${CYVERSE_BASE}/${RUNID}/bwa-index/nt${chunk}.fasta*"
    echo "https://data.cyverse.org/dav-anon/${CYVERSE_BASE}/${RUNID}/bwa-index/nt${chunk}.fasta" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/${CYVERSE_BASE}/${RUNID}/bwa-index/nt${chunk}.fasta.amb" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/${CYVERSE_BASE}/${RUNID}/bwa-index/nt${chunk}.fasta.ann" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/${CYVERSE_BASE}/${RUNID}/bwa-index/nt${chunk}.fasta.bwt" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/${CYVERSE_BASE}/${RUNID}/bwa-index/nt${chunk}.fasta.pac" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/${CYVERSE_BASE}/${RUNID}/bwa-index/nt${chunk}.fasta.sa" >> ${URLS}

    #download index
    mkdir ${INDEX}
    echo "cat ${URLS} | xargs nugget -q -t -c -s 6 -d ${INDEX}"
    cat ${URLS} | xargs nugget -q -t -c -s 6 -d ${INDEX}
    wait $!
    rm ${URLS}

    #run bwa mem on each primer
    for ecopcrfasta in $ECOPCR
    do
        echo $ecopcrfasta
        ecopcrfasta=$ecopcrfasta | tr -d '.fasta\n'
        primer=$(basename $ecopcrfasta)
        primer=$(echo "${primer%.*}")

        fasta=$(find ${INDEX}/*.fasta -type f)
        nt=$(basename $fasta)
        echo "time bwa mem -a -t ${THREADS} ${fasta} ${ecopcrfasta} | samtools view -bS - > ${OUTPUT}/${primer}-${nt}.bam"
        time bwa mem -a -t ${THREADS} ${fasta} ${ecopcrfasta} | samtools view -bS - > ${OUTPUT}/${primer}-${nt}.bam
    done
    # rm files to save space
    rm ${INDEX}/*

done

# upload files to cyverse
echo "gocmd put -c ${CYVERSE} ${OUTPUT}/* ${CYVERSE_BASE}/${RUNID}/bwa-mem/"
gocmd put -c ${CYVERSE} ${OUTPUT}/* ${CYVERSE_BASE}/${RUNID}/bwa-mem/
