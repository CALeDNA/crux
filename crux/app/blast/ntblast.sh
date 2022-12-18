#! /bin/bash

set -x
set -o allexport

NTDB="nt"
NTFILE="nt-cyverse"
#mkdir ${NTDB}

CONFIG="config.yaml"
HOSTNAME=""
vars="/vars"

while getopts "h:c:v:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        v) VARS="$OPTARG"
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${HOSTNAME} && ! -z ${CONFIG} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -c, -i, -h and -o"
  echo ""
  exit
fi

cd /mnt
cp ${VARS}/* .
source ${CONFIG}

ECOPCR=$(find ecopcr/ -maxdepth 1 -type f)
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
       START=$(( $HOSTNAME * $SCALE  + $HOSTNAME ))
       END=$(( $START + $SCALE + 1 ))
   else
       START=$(( $HOSTNAME * $SCALE + $REMAINDER ))
       END=$(( $START + $SCALE ))
   fi
fi

# get file with nt cyverse urls
gocmd get -c ${CYVERSE} "/iplant/home/shared/eDNA_Explorer/crux/${NTFILE}" .
# remove all urls except from [START,END]
sed -ni "${START}, ${END}p" ${NTFILE}

eVALUE="0.00001"
PERC_IDENTITY="50"
NUM_ALIGNMENTS="100"
GAP_OPEN="1"
GAP_EXTEND="1"

blast () {
    set -x
    url=$1
    ((nt=$2-1))
    chunk=$( basename $url | sed 's/[^0-9]*//g' ) # get nt chunk number
    # ((nt=10#$nt)) 
    chunk=$(printf '%02d' "${10#$chunk}")
    gocmd get -c ${CYVERSE} "/iplant/home/shared/eDNA_Explorer/nt/nt.${chunk}.tar.gz" ${NTDB}${nt}/nt.${chunk}.tar.gz
    gocmd get -c ${CYVERSE} "/iplant/home/shared/eDNA_Explorer/crux/nt-fasta/nt${chunk}.fasta" .
    tar -xf ${NTDB}${nt}/nt.${chunk}.tar.gz -C ${NTDB}${nt}
    sed -i "s/^DBLIST.*/DBLIST nt.${chunk} /" ${NTDB}${nt}/nt.nal
    
    for ecopcrfasta in $ECOPCR
    do
        input=$ecopcrfasta | tr -d '.fasta\n'
        primer=$(basename $input)
        primer=$(echo "${primer%.*}")
        output="${input}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta"
        input="${input}.fasta"
        time blastn -query ${input} -out ${output}_${nt}.txt -db ${NTDB}${nt}/nt -outfmt "6 saccver staxid sseq" -num_threads 4 -evalue ${eVALUE} -perc_identity ${PERC_IDENTITY} -num_alignments ${NUM_ALIGNMENTS} -gapopen ${GAP_OPEN} -gapextend ${GAP_EXTEND}
        cat ${output}_${nt}.txt >> ${output}_${nt}
        rm ${output}_${nt}.txt
    done
    rm nt${chunk}.fasta ${NTDB}${nt}/nt.${chunk}*
}

# get nt00 files in each folder
mkdir ${NTDB}0
gocmd get -c ${CYVERSE} "/iplant/home/shared/eDNA_Explorer/nt/nt.00.tar.gz" ${NTDB}0/nt.00.tar.gz
tar -xf ${NTDB}0/nt.00.tar.gz -C ${NTDB}0
rm ${NTDB}0/nt.00*
N=4
for i in {1..3}
do
    mkdir ${NTDB}${i}
    cp ${NTDB}0/* ${NTDB}${i}
done

cat ${NTFILE} | parallel -I{} --tag --max-args 1 -P ${N} blast {} {%} 


for ecopcrfasta in $ECOPCR
do
    primer=$ecopcrfasta | tr -d '.fasta\n'
    primer=$(basename $primer)
    primer=$(echo "${primer%.*}")
    output="${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta"

    find . -maxdepth 1 -name "${output}_*" | xargs -i sh -c 'cat {} >> ${output} && rm {}'
done
echo "Done"
#TODO: upload to cyverse
