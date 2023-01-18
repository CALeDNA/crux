#! /bin/bash

set -x
set -o allexport

NTDB="nt"
# NTFILE="nt-ftp"
# mkdir ${NTDB}

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
if [[ ! -z ${HOSTNAME} && ! -z ${CONFIG} && ! -z ${VARS} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -c, -h and -v"
  echo ""
  exit
fi

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

# remove all urls except from [START,END]
linestart=$(( $START + 1 ))
lineend=$(( $END + 1))
sed -ni "${linestart}, ${lineend}p" ${NTFILE}

eVALUE="0.00001"
PERC_IDENTITY="70"
NUM_ALIGNMENTS="1000"
GAP_OPEN="1"
GAP_EXTEND="1"

blast () {
    set -x
    url=$1
    ((nt=$2-1))
    chunk=$( basename $url | sed 's/[^0-9]*//g' ) # get nt chunk number
    # ((nt=10#$nt)) 
    $((chunk=10#$chunk))
    chunk=$(printf '%02d' $chunk)
    wget -q --retry-connrefused --timeout=300 --tries=inf --continue -P ${NTDB}${nt} ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt.${chunk}.tar.gz
    # gocmd get -c ${CYVERSE} "/iplant/home/shared/eDNA_Explorer/nt/nt.${chunk}.tar.gz" ${NTDB}${nt}/nt.${chunk}.tar.gz
    # gocmd get -c ${CYVERSE} "/iplant/home/shared/eDNA_Explorer/crux/nt-fasta/nt${chunk}.fasta" .
    tar -xf ${NTDB}${nt}/nt.${chunk}.tar.gz -C ${NTDB}${nt}
    sed -i "s/^DBLIST.*/DBLIST nt.${chunk} /" ${NTDB}${nt}/nt.nal
    blastdbcmd -entry all -db ${NTDB}${nt}/nt -out ./nt${chunk}.fasta
    
    for ecopcrfasta in $ECOPCR
    do
        #TODO: if aws s3api head-object --bucket www.codeengine.com --key index.html .. then
        input=$(echo $ecopcrfasta | cut -d\. -f1 )
        primer=$(basename $input)
        primer=$(echo "${primer%.*}")
        output="${input}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta"
        input="${input}.fasta"

        # check if blast already ran this (primer,nt) pair
        not_exists=$(aws s3api head-object --bucket ednaexplorer --key crux/${RUNID}/blast/ecopcr/${output}_${chunk} --endpoint-url https://js2.jetstream-cloud.org:8001/ >/dev/null 2>1; echo $?)
        if [ $not_exists == 255 ];
        then
            # file does not exist. run blast
            time blastn -query ${input} -out ${output}_${chunk} -db ${NTDB}${nt}/nt -outfmt "6 saccver staxid sseq" -num_threads 4 -evalue ${eVALUE} -perc_identity ${PERC_IDENTITY} -num_alignments ${NUM_ALIGNMENTS} -gapopen ${GAP_OPEN} -gapextend ${GAP_EXTEND}
            aws s3 cp ${output}_${chunk}  s3://ednaexplorer/crux/${RUNID}/blast/${output}_${chunk} --endpoint-url https://js2.jetstream-cloud.org:8001/
            rm ${output}_${chunk}
        else
            # file exists. checking if empty"
            length=$(aws s3api head-object --bucket ednaexplorer --key crux/${RUNID}/blast/ecopcr/${output}_${chunk} --endpoint-url https://js2.jetstream-cloud.org:8001/ | jq ".ContentLength")
            if (( $length > 0 )); 
            then
                 echo "skipping $file"
            else
                # empty file exists. rerun blast just in case
                time blastn -query ${input} -out ${output}_${chunk} -db ${NTDB}${nt}/nt -outfmt "6 saccver staxid sseq" -num_threads 4 -evalue ${eVALUE} -perc_identity ${PERC_IDENTITY} -num_alignments ${NUM_ALIGNMENTS} -gapopen ${GAP_OPEN} -gapextend ${GAP_EXTEND}
                aws s3 cp ${output}_${chunk}  s3://ednaexplorer/crux/${RUNID}/blast/${output}_${chunk} --endpoint-url https://js2.jetstream-cloud.org:8001/
                rm ${output}_${chunk}
            fi
        fi
    done
    rm nt${chunk}.fasta ${NTDB}${nt}/nt.${chunk}*
}

# get nt00 files in each folder
mkdir ${NTDB}0
wget -q --retry-connrefused --timeout=45 --tries=inf --continue -P ${NTDB}0 ftp://ftp.ncbi.nlm.nih.gov/blast/db/nt.00.tar.gz
# gocmd get -c ${CYVERSE} "/iplant/home/shared/eDNA_Explorer/nt/nt.00.tar.gz" ${NTDB}0/nt.00.tar.gz
tar -xf ${NTDB}0/nt.00.tar.gz -C ${NTDB}0
rm ${NTDB}0/nt.00*
N=4
for i in {1..3}
do
    mkdir ${NTDB}${i}
    cp ${NTDB}0/* ${NTDB}${i}
done

cat ${NTFILE} | parallel -I{} --tag --max-args 1 -P ${N} blast {} {%} 


#TODO: combine all fasta chunks into 1
# for ecopcrfasta in $ECOPCR
# do
#     primer=$(echo $ecopcrfasta | cut -d\. -f1 )
#     primer=$(basename $primer)
#     primer=$(echo "${primer%.*}")
#     output="${primer}_blast_${NUM_ALIGNMENTS}_${PERC_IDENTITY}_${primer}.fasta"

#     find ./ecopcr -maxdepth 1 -name "${output}_*" | xargs -i sh -c 'cat {} >> ${output} && rm {}'
#     aws s3 cp ${output}  s3://ednaexplorer/crux/${RUNID}/blast/${primer}_blast_${HOSTNAME}.fasta --endpoint-url https://js2.jetstream-cloud.org:8001/
# done
echo "Done"
