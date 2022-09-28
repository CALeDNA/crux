#! /bin/bash
NTDB=""
OUTPUT=""
INDEX=""
RUNID=""
CONFIG=""

while getopts "n:i:r:h:c:" opt; do
    case $opt in
        n) NTDB="$OPTARG"
        ;;
        i) INDEX="$OPTARG" 
        ;;
        r) RUNID="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
    esac
done

source ${CONFIG}

#Check that user has all of the default flags set
if [[ ! -z ${NTDB} && ! -z ${INDEX} && ! -z ${RUNID} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -n, -i and -o"
  echo ""
  exit
fi

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

# first, download nt00 extra files that aren't in the other nt chunks
wget -q -c --tries=0 -P ${NTDB} https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/nt/nt.00.tar.gz
tar -xf ${NTDB}/nt.00.tar.gz -C ${NTDB}
rm ${NTDB}/nt.00*

# download nt file from cyverse and untar it
# then run blastdbcmd to create fasta file
for (( i=${START}; i<${END}; i++ ))
do
    chunk=$(printf '%02d' "$i")
    echo "wget -c --tries=0 -P ${NTDB} https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/nt/nt.${chunk}.tar.gz"
    wget -q -c --tries=0 -P ${NTDB} https://data.cyverse.org/dav-anon/iplant/projects/eDNA_Explorer/nt/nt.${chunk}.tar.gz
    tar -xf ${NTDB}/nt.${chunk}.tar.gz -C ${NTDB}
    sed -i "s/^DBLIST.*/DBLIST nt.${chunk} /" ${NTDB}/nt.nal
    echo "blastdbcmd -entry all -db ${NTDB}/nt -out ${INDEX}/nt${chunk}.fasta"
    blastdbcmd -entry all -db ${NTDB}/nt -out ${INDEX}/nt${chunk}.fasta
    rm ${NTDB}/nt.${chunk}.*
done

# build bwa index and upload to cyverse
echo "find ${INDEX}/*.fasta -type f | parallel -I% --tag --max-args 1 -P ${INDEX_THREADS} ./parallel_index.sh -a bwtsw -b 100000000 -f % -c ${CONFIG}"
find ${INDEX}/*.fasta -type f | parallel -I% --tag --max-args 1 -P ${INDEX_THREADS} ./parallel_index.sh -a bwtsw -b 100000000 -f % -c ${CONFIG}