#! /bin/bash

INPUT="." # folder containing {1..n}.fasta
OUTPUT="." # folder to output results
NUCLGB="nucl_gb.accession2taxid"
while getopts "i:o:gwb" opt; do
    case $opt in
        i) INPUT="$OPTARG"
        ;;
        o) OUTPUT="$OPTARG"
        ;;
        g) GENBANK=true
        ;;
        w) WGS=true
        ;;
        b) BLAST=true
        ;;
    esac
done

genbank () {
    cat ${INPUT} | while read line
    do
        # echo $line
        if [[ $line = ">"* ]]
        then
            # echo "$line"
            taxid=$(echo "$line" | awk -F';' '{for(i=1;i<=NF;i++){if($i ~ /TAXID/){print $i}}}' | cut -d'=' -f2) #taxid
            genbank=$(echo "$line" | awk -F';' '{for(i=1;i<=NF;i++){if($i ~ />/){print $i}}}' | cut -d' ' -f1 | tr -d ">")
            echo "$genbank  $taxid" >> $OUTPUT
            # if [[ "$line" =~ ( ) ]]
            # then
        fi
    done
}

blast () {
    echo "blast"
    python3 blast2taxid.py --input $INPUT --output $OUTPUT
}

wgs () {
    echo "wgs / nt blast"
    python3 wgs2taxid.py --input $INPUT --output $OUTPUT --nucltaxid $NUCLGB --log 'logs'
}

if [[ $GENBANK ]] 
then
    echo "genbank"
    genbank
fi

if [[ $WGS ]] 
then
    echo "wgs"
    wgs
fi

if [[ $BLAST ]] 
then
    echo "blast"
    blast
fi