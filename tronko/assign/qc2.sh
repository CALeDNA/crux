#! /bin/bash

export AWS_MAX_ATTEMPTS=3

OUTPUT="/etc/ben/output"
RUNID="2023-04-07"
while getopts "i:p:b:" opt; do
    case $opt in
        i) PROJECTID="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        b) BENSERVER="$OPTARG"
        ;;
        *) echo "usage: $0 [-i] [-p] [-b]" >&2
            exit 1 ;;
    esac
done

# download $PROJECTID/QC primers, checksum and samples
aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/QC ${PROJECTID}-$PRIMER/ --exclude "*/*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/QC/$PRIMER ${PROJECTID}-$PRIMER/ --exclude "*/*" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/samples ${PROJECTID}-$PRIMER/samples --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# download Anacapa
git clone -b cruxv2 https://github.com/CALeDNA/Anacapa.git



# Only keep files that haven't been ran through QC
checksums_file="${PROJECTID}-$PRIMER/checksums.txt"
# check if it's been run before
if [ -e $checksums_file ]; then
    # Check if any files in md5sum file were deleted
    # Create a temporary file
    temp_file=$(mktemp)
    # List objects in the S3 bucket that match the prefix
    objects=$(aws s3 ls "s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER" --recursive --endpoint-url https://js2.jetstream-cloud.org:8001/ | awk '{print $4}')
    # Loop through the lines in the checksum file
    while IFS= read -r line; do
        # Extract the checksum and file path
        md5_checksum=$(echo "$line" | awk '{print $1}')
        file_path=$(echo "$line" | awk '{ $1=""; print $0 }' | xargs )

        # Check if the file exists
        if [ -f "$file_path" ]; then
            # If the file exists, add the line to the temporary file
            echo "$line" >> "$temp_file"
        else
            # If previously run file no longer exists in samples, delete it from QC $PRIMER js2 folder
            echo "File '$file_path' no longer exists in samples. Deleting $PRIMER QC file..."
            file_name=$(basename "$line" | sed -E 's/_R[12]_001\.fastq\.gz$//' | tr '_' '-')

            # pattern to match
            pattern="${PRIMER}_${file_name}"

            # Loop through the objects and delete the ones that match the pattern
            for object in $objects; do
            if [[ $object == *"$pattern"* ]]; then
                aws s3 rm s3://ednaexplorer/$object --endpoint-url https://js2.jetstream-cloud.org:8001/
                echo "Deleted: $object"
            fi
            done
        fi
    done < "$checksums_file"
    mv $temp_file $checksums_file


    declare -A checksums

    # Read checksums from the file into the associative array
    while read -r checksum filename; do
        echo $filename
        echo $checksum
        checksums["$filename"]=$checksum
    done < "$checksums_file"

    # Loop through the files in the directory
    for file in "${PROJECTID}-$PRIMER/samples/"*; do
        # Check if the file exists in the associative array
        if [[ -n ${checksums["$file"]} ]]; then
            echo "File $file exists in checksums.txt."
            echo "Checking checksums..."
            new_md5sum=$(md5sum $file | cut -d' ' -f1)
            if [ "${checksums["$file"]}" = "$new_md5sum" ]; then
                echo "MD5 checksums are the same. Deleting..."
                rm $file
            else
                echo "MD5 checksums are different. Keeping $file"
            fi
        else
            echo "File does not exist in checksums.txt. Keeping $file"
            md5sum "$file" >> "$checksums_file"
        fi
    done

    # upload new checksums
    aws s3 cp $checksums_file s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/checksums.txt --endpoint-url https://js2.jetstream-cloud.org:8001/
else
    echo "MD5 file does not exist. Keeping all files."
    # create md5 checksum
    for file in "${PROJECTID}-$PRIMER/samples/"*; do
        md5sum "$file" >> $checksums_file
    done
    # upload checksums
    aws s3 cp $checksums_file s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/checksums.txt --endpoint-url https://js2.jetstream-cloud.org:8001/
fi



# Run QC

# EDIT THESE
BASEDIR="./Anacapa"
DB="$BASEDIR/Anacapa_db"
DATA="./$PROJECTID-$PRIMER/samples"
OUT="./$PROJECTID-$PRIMER/${PROJECTID}QC"

# OPTIONAL
FORWARD="./$PROJECTID-$PRIMER/forward_primers.txt"
REVERSE="./$PROJECTID-$PRIMER/reverse_primers.txt"
LENGTH="./$PROJECTID-$PRIMER/metabarcode_loci_min_merge_length.txt"


# modify forward/reverse to only include $PRIMER information
grep -A 1 ">$PRIMER" "$FORWARD" > tmp
mv tmp "$FORWARD"
grep -A 1 ">$PRIMER" "$REVERSE" > tmp
mv tmp "$REVERSE"

time $DB/anacapa_QC_dada2.sh -i $DATA -o $OUT -d $DB -f $FORWARD -r $REVERSE -m 50 -q 30

# upload $OUT
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/paired/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/paired --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_F/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_F --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_R/filtered s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/unpaired_R --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# upload QC logs
aws s3 sync $PROJECTID-$PRIMER/${PROJECTID}QC/Run_info s3://ednaexplorer/projects/$PROJECTID/QC/$PRIMER/Run_info --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/


# add ben tronko-assign jobs
# check if paired folder has files
paired_files=$(ls -A "$PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/paired/filtered" | wc -l)
unpaired_F_files=$(ls -A "$PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_F/filtered" | wc -l)
unpaired_R_files=$(ls -A "$PROJECTID-$PRIMER/${PROJECTID}QC/$PRIMER/${PRIMER}_sort_by_read_type/unpaired_R/filtered" | wc -l)
parameters=""
if [ "$paired_files" -gt 0 ]; then
    parameters+="-1"
fi
if [ "$unpaired_F_files" -gt 0 ]; then
    parameters+=" -2"
fi
if [ "$unpaired_R_files" -gt 0 ]; then
    parameters+=" -3"
fi

# add tronko assign job on $PRIMER
ben add -s $BENSERVER -c "docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -v /tmp:/tmp -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_S3_ACCESS_KEY_ID=$AWS_S3_ACCESS_KEY_ID -e AWS_S3_SECRET_ACCESS_KEY=$AWS_S3_SECRET_ACCESS_KEY -e AWS_S3_DEFAULT_REGION=$AWS_S3_DEFAULT_REGION -e AWS_S3_BUCKET=$AWS_S3_BUCKET --name $PROJECTID-assign-$PRIMER crux /mnt/assign.sh -i $PROJECTID -r $RUNID -p $PRIMER $parameters" $PROJECTID-assign-$PRIMER -o $OUTPUT

# clean up
rm -r /mnt/$PROJECTID-$PRIMER /mnt/Anacapa
