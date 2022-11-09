#!/bin/bash

set -x

GENBANK="" # file containing genbank links
PRIMERS="" # file containing list of primers
OUTPUT="" # folder to output fasta files
BATCHTAG="" # batch tag
ERROR="" # ecopcr error
MINLENGTH="" # ecopcr min length
MAXLENGTH="" # ecopcr max length

while getopts "g:p:o:b:e:s:l:c:" opt; do
    case $opt in
        g) GENBANK="$OPTARG"
        ;;
        p) PRIMERS="$OPTARG"
        ;;
        o) OUTPUT="$OPTARG"
        ;;
        b) BATCHTAG="$(basename $OPTARG)"
        ;;
        e) ERROR="$OPTARG"
        ;;
        s) MINLENGTH="$OPTARG"
        ;;
        l) MAXLENGTH="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
    esac
done
echo "${BATCHTAG}"

source ${CONFIG}

LINKS=$(cat $GENBANK)
PRIMERS=$(cat $PRIMERS)

#import tax db
#cp -R taxdump tax${BATCHTAG}/
mkdir tax${BATCHTAG}${BATCHTAG}; cd tax${BATCHTAG}${BATCHTAG}; mkdir ${OUTPUT}; cp ../taxdump.tar.gz .
TAXDB="tax${BATCHTAG}/taxonomy/taxdump"
obi import --taxdump taxdump.tar.gz ${TAXDB}
# TAXDB=tax${BATCHTAG}${BATCHTAG}/tax${BATCHTAG}/taxonomy/taxdump
# cd ..
# cp -R tax.obidms tax${BATCHTAG}.obidms

for link in $LINKS
do
    for i in {1..5} # retry up to 5 times if any step of obi ecopcr fails
    do
        wget -q --retry-connrefused --timeout=45 --tries=inf --continue -P GB/ ${link} &&
        filename=$(basename "$link") &&
        name="${filename%.gbff.gz}" &&

        timeout -v 600s obi import --genbank-input GB/${filename} gb${name}/${name} &&
        
        for primer in ${PRIMERS}
        do
            FP=$( echo ${primer} | cut -d ',' -f1 ) && # split primer into FP and RP then obi ecopcr then export and combine fasta output
            RP=$( echo ${primer} | cut -d ',' -f2 ) &&
            PRIMERNAME=$( echo ${primer} | cut -d ',' -f3 ) &&
            if [ $MAXLENGTH -eq 0 ]
            then
                obi ecopcr -e ${ERROR} -l ${MINLENGTH} -F ${FP} -R ${RP} --taxonomy ${TAXDB} gb${name}/${name} output${name}_${PRIMERNAME}/${name} &&
            else
                obi ecopcr -e ${ERROR} -l ${MINLENGTH} -L ${MAXLENGTH} -F ${FP} -R ${RP} --taxonomy ${TAXDB} gb${name}/${name} output${name}_${PRIMERNAME}/${name}
            fi &&
            obi export --fasta-output output${name}_${PRIMERNAME}/${name} -o tmp${name}_${PRIMERNAME}.fasta &&
            cat tmp${name}_${PRIMERNAME}.fasta >> ${OUTPUT}/out_${BATCHTAG}_${PRIMERNAME}.fasta &&

            #clean obitools databases
            obi clean_dms tax${BATCHTAG} &&
            obi clean_dms gb${name} &&
            # delete files
            rm -r output${name}_${PRIMERNAME}.obidms &&
            rm tmp${name}_${PRIMERNAME}.fasta
        done &&
        # clean genbank input
        rm -r gb${name}.obidms &&
        rm GB/${filename} &&

        echo "Successful obi ecopcr $name" &&
        break ||
        
        echo "Obi ecopcr failed. Cleaning and retrying $name" &&
        #clean obitools databases
        obi clean_dms tax${BATCHTAG} &&
        obi clean_dms gb${name} &&
        # delete files
        rm -r output${name}_${PRIMERNAME}.obidms &&
        rm tmp${name}_${PRIMERNAME}.fasta &&
        rm ${OUTPUT}/out_${BATCHTAG}_${PRIMERNAME}.fasta
    done

done
# rm tmp.fasta
mv ${OUTPUT}/* ../${OUTPUT}
cd ../
# remove tax folder
rm -r tax${BATCHTAG}${BATCHTAG}
