#! /bin/bash
OUTPUT=""
INDEX=""
RUNID=""
# HOSTNAME=$(hostname | tr -dc '0-9')
THREADS=3
URLS="chunks.txt"
CYVERSE="config.yaml"

while getopts "o:i:r:h:" opt; do
    case $opt in
        o) OUTPUT="$OPTARG"
        ;;
        i) INDEX="$OPTARG" 
        ;;
        r) RUNID="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${OUTPUT} && ! -z ${INDEX} && ! -z ${RUNID} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -n, -o and -i"
  echo ""
  exit
fi

ECOPCR=$(find ecopcr/${RUNID}/ -maxdepth 1 -type f)
# # configured for 10 VM and 71 NT chunks
# NAME=$(hostname | tr -dc '0-9')
# HOSTNAME=${NAME#0}
# HOSTNAME=$((HOSTNAME * 7))
# end=$((HOSTNAME + 7))
# if (( end > 65 ));
# then
#     end=$(( end + 1 ))
# fi
START=$(( $HOSTNAME * 2 + 2))
END=$((START + 2))
# HOSTNAME="16"
# end="18"

# SCALE=$(( ( $NTOTAL + ($NUMINSTANCES / 2) ) / $NUMINSTANCES )) # round to nearest whole number
# START=$(( $HOSTNAME * $SCALE ))
# END=$(( $START + $SCALE ))
# if (( $NTOTAL - ( $END - 1) < $SCALE ))
# then
#     END=${NTOTAL}
# fi

for (( c=${START}; c<${END}; c++ ))
do
    chunk=$(printf '%02d' "$c")
    echo "https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/bwa/bwa-index/${RUNID}/nt${chunk}.fasta" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/bwa/bwa-index/${RUNID}/nt${chunk}.fasta.amb" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/bwa/bwa-index/${RUNID}/nt${chunk}.fasta.ann" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/bwa/bwa-index/${RUNID}/nt${chunk}.fasta.bwt" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/bwa/bwa-index/${RUNID}/nt${chunk}.fasta.pac" >> ${URLS}
    echo "https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/bwa/bwa-index/${RUNID}/nt${chunk}.fasta.sa" >> ${URLS}

    #download index
    mkdir ${INDEX}
    cat ${URLS} | xargs nugget -q -t -c -s 6 -d ${INDEX}
    wait $!
    rm ${URLS}

    mkdir ${OUTPUT}/${RUNID}

    #run bwa mem on each primer
    for ecopcrfasta in $ECOPCR
    do
        echo $ecopcrfasta
        ecopcrfasta=$ecopcrfasta | tr -d '.fasta\n'
        primer=$(basename $ecopcrfasta)
        primer=$(echo "${primer%.*}")

        fasta=$(find ${INDEX}/*.fasta -type f)
        nt=$(basename $fasta)
        echo "time bwa mem -a -t ${THREADS} ${fasta} ${ecopcrfasta} | samtools view -bS - > ${OUTPUT}/${RUNID}/${primer}-${nt}.bam"
        time bwa mem -a -t ${THREADS} ${fasta} ${ecopcrfasta} | samtools view -bS - > ${OUTPUT}/${RUNID}/${primer}-${nt}.bam
        # combine sam files by primer
        # samtools merge ${OUTPUT}/${primer}-${NAME}.bam ${OUTPUT}/${primer}*
        # upload combined file to cyverse
        #rm ${OUTPUT}/*
    done
    # rm files to save space
    rm ${INDEX}/*

done

# upload files to cyverse
echo "gocmd put -e ${OUTPUT}/${RUNID} /iplant/home/shared/eDNA_Explorer/bwa/bwa-output/"
gocmd put -c ${CYVERSE} ${OUTPUT}/${RUNID} /iplant/home/shared/eDNA_Explorer/bwa/bwa-output/
