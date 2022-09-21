#! /bin/bash
NTDB=""
OUTPUT=""
INDEX=""
RUNID=""
CYVERSE="config.yaml"

while getopts "n:i:r:h:" opt; do
    case $opt in
        n) NTDB="$OPTARG"
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

START=$(( $HOSTNAME * 2 + 2))
END=$((START + 2))


# SCALE=$(( ( $NTOTAL + ($NUMINSTANCES / 2) ) / $NUMINSTANCES )) # round to nearest whole number
# START=$(( $HOSTNAME * $SCALE ))
# END=$(( $START + $SCALE ))
# if (( $NTOTAL - ( $END - 1) < $SCALE ))
# then
#     END=${NTOTAL}
# fi

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

# build bwa index
echo "find ${INDEX}/*.fasta -type f | parallel -I% --tag --max-args 1 -P 3 time bwa index -a bwtsw -b 100000000 %"
find ${INDEX}/*.fasta -type f | parallel -I% --tag --max-args 1 -P 3 time bwa index -a bwtsw -b 100000000 %

# upload indexes to cyverse
mv ${INDEX}/ ${RUNID}/
gocmd put -c ${CYVERSE} ${RUNID}/ /iplant/home/shared/eDNA_Explorer/bwa/bwa-index
rm -r ${RUNID}
