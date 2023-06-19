#! /bin/bash
set -x

OUTPUT="/etc/ben/output"
PAIRED=""
UNPAIRED_F=""
UNPAIRED_R=""
while getopts "f:i:p:123" opt; do
    case $opt in
        f) FILE="$OPTARG"
        ;;
        i) PROJECTID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        1) PAIRED="TRUE"
        ;;
        2) UNPAIRED_F="TRUE"
        ;;
        3) UNPAIRED_R="TRUE"
        ;;
    esac
done

source /vars/crux_vars.sh # to get tronko db run ID

check_mismatches() {
    # check if there's mismatches under 5
    # returns true if there's at least 1 row with < 5 mismatches
    line_exists=false
    path="$1"  # Assign the path argument to a variable
    for file in "$path"/*.txt; do
        # Check if the file exists and is readable
        if [[ -f "$file" && -r "$file" ]]; then
            first_line=true
            # Check if there is a line where both the 4th and 5th columns have values less than 5
            while IFS=$'\t' read -r line; do
                # skip header
                if $first_line; then
                    first_line=false
                    continue
                fi
                col4=$(echo "$line" | awk -F'\t' '{ if (NF >= 4) print $4; else print 5 }')
                col5=$(echo "$line" | awk -F'\t' '{ if (NF >= 5) print $5; else print 5 }')
                if (( $(echo "$col4 < 5" | bc -l) )) && (( $(echo "$col5 < 5" | bc -l) )); then
                    line_exists=true
                    echo "$col4 $col5"
                    break
                fi
            done < "$file"
            if $line_exists; then
                echo "line exists"
                break
            fi
        fi
    done

    # Returns true if a line with less than 5 mismatches exists, false otherwise
    $line_exists
}


if [ "${PAIRED}" = "TRUE" ]
then
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample paired files
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -p -z -w -q -1 $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -2 $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt

    # check if there's no mismatches under 5
    if ! check_mismatches "$PROJECTID-$FILE"; then
        # cleanup old assign output
        rm $PROJECTID-$FILE/*.txt
        # rerun tronko assign paired with -1 and -2 switched
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -p -z -w -q -1 -2 $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -2 $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt
    fi

    # upload to aws
    aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/paired/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm -r $PROJECTID-$FILE/*
fi

if [ "${UNPAIRED_F}" = "TRUE" ]
then
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample unpaired_F
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt

    # check if there's no mismatches under 5
    if ! check_mismatches "$PROJECTID-$FILE"; then
        # cleanup old assign output
        rm $PROJECTID-$FILE/*.txt
        # rerun tronko assign unpaired_F with -v option
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_F_filt.fastq.gz -6 -C 1 -c 5 -v -o $PROJECTID-$FILE/$FILE.txt
    fi

    # upload to aws
    aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_F/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm -r $PROJECTID-$FILE/*
fi

if [ "${UNPAIRED_R}" = "TRUE" ]
then
    # download tronko database
    aws s3 sync s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/tronko $PROJECTID-$FILE/tronkodb/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
    
    # download QC sample unpaired_R
    aws s3 sync s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R/ $PROJECTID-$FILE/ --exclude '*' --include "${FILE}*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # run tronko assign
    tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -v -o $PROJECTID-$FILE/$FILE.txt

    # check if there's no mismatches under 5
    if ! check_mismatches "$PROJECTID-$FILE"; then
        # cleanup old assign output
        rm $PROJECTID-$FILE/*.txt
        # rerun tronko assign unpaired_R without -v option
        tronko-assign -r -f $PROJECTID-$FILE/tronkodb/reference_tree.txt.gz -a $PROJECTID-$FILE/tronkodb/$PRIMER.fasta -s -w -q -g $PROJECTID-$FILE/${FILE}_R_filt.fastq.gz -6 -C 1 -c 5 -o $PROJECTID-$FILE/$FILE.txt
    fi

    # upload to aws
    aws s3 cp $PROJECTID-$FILE/$FILE.txt s3://ednaexplorer/projects/$PROJECTID/assign/$PRIMER/unpaired_R/$FILE.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

    # cleanup
    rm -r $PROJECTID-$FILE/*
fi



# paired:
# check if theres no mismatches under 5 
# switch -1 and -2 files and rerun
# then, pick the output file with the most lines with mismatches under 5

# if theres no mismatches under 5 
# in upaired_F, then run with -v
# then, pick the output file with the most lines with mismatches under 5

# unpaired_R:
# run without -v

# cleanup
rm -r $PROJECTID-$FILE