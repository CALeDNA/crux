#! /bin/bash

export AWS_MAX_ATTEMPTS=3

OUTPUT="/etc/ben/output"
INPUT_METADATA="METABARCODING.csv"
BENPATH="/etc/ben/ben"
ADAPTER="nextera"
PROJECTID_LOG="$OUTPUT/projectids.txt"
MISSINGMARKERS="$OUTPUT/missingmarkers.json"
while getopts "p:b:k:s:r:K:S:R:B:" opt; do
    case $opt in
        p) PROJECTID="$OPTARG"
        ;;
        b) BENSERVER="$OPTARG"
        ;;
        k) AWS_ACCESS_KEY_ID="$OPTARG"
        ;;
        s) AWS_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        r) AWS_DEFAULT_REGION="$OPTARG"
        ;;
        K) AWS_S3_ACCESS_KEY_ID="$OPTARG"
        ;;
        S) AWS_S3_SECRET_ACCESS_KEY="$OPTARG"
        ;;
        R) AWS_S3_DEFAULT_REGION="$OPTARG"
        ;;
        B) AWS_S3_BUCKET="$OPTARG"
        ;;
    esac
done

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# make project folder
mkdir $PROJECTID

# touch files
touch $PROJECTID/forward_primers.txt
touch $PROJECTID/reverse_primers.txt
touch $PROJECTID/metabarcode_loci_min_merge_length.txt

# download metadata file
aws s3 cp s3://ednaexplorer/projects/${PROJECTID}/$INPUT_METADATA ${PROJECTID}/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
# download primer master sheet
aws s3 cp s3://ednaexplorer/CruxV2/eDNAExplorerPrimers.csv ${PROJECTID}/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# Read the header row and split it into an array
IFS="," read -ra headers < "$PROJECTID/$INPUT_METADATA"

# Loop through the headers and find the positions of columns matching the pattern "Marker N"
marker_positions=()
adapter_position="-1"
for i in "${!headers[@]}"; do
    if [[ "${headers[$i]}" =~ ^Marker\ [0-9]+$ ]]; then
        marker_positions+=("$i")
    elif [[ "${headers[$i]}" =~ "Adapter Type" ]]; then
        adapter_position=$i
    fi
done

echo "Positions of columns matching 'Marker N': ${marker_positions[@]}"

# Create an associative array (hash map) to store unique Marker and their corresponding FP and RP columns
declare -A unique_values
# set flag variable
adapter_position_processed=false

# Loop through the CSV file rows (excluding the header row)
while IFS="," read -ra row; do
    for position in "${marker_positions[@]}"; do
        current_value="${row[$position]}"
        if [[ -n "$current_value" ]]; then
            if [[ -z "${unique_values[$current_value]}" ]]; then
                unique_values["$current_value"]="${row[$position+1]} ${row[$position+2]}"
            fi
        fi
    done
    if [ "$adapter_position" != "-1" ] && [ "$adapter_position_processed" = false ]; then
        ADAPTER="${row[$adapter_position]}"
        ADAPTER="${ADAPTER,,}" # convert to lower case
        adapter_position_processed=true
    fi # else using "nextera" as default
done < <(tail -n +2 "$PROJECTID/$INPUT_METADATA" | tr -d '\r')

# Print the unique Markers and their corresponding FP and RP columns
for value in "${!unique_values[@]}"; do
    echo "Unique Marker: $value"
    echo "Forward and Reverse Primers: ${unique_values[$value]}"
    echo "--------------------"
done

# Loop through eDNAExplorerPrimers file and check if the Marker ID and FP/RP columns appear in the same row
while IFS="," read -ra row; do
    marker_value="${row[1]}"
    FP="${row[2]}"
    RP="${row[3]}"
    for key in "${!unique_values[@]}"; do
        if [[ "${unique_values[$key]}" == "$FP $RP" ]]; then
            echo "Unique marker '$marker_value' and its corresponding primers appear in $INPUT_METADATA"

            # Add Primer for QC
            echo ">$marker_value" >> $PROJECTID/forward_primers.txt
            echo "${row[2]}" >> $PROJECTID/forward_primers.txt

            echo ">$marker_value" >> $PROJECTID/reverse_primers.txt
            echo "${row[3]}" >> $PROJECTID/reverse_primers.txt

            echo "LENGTH_$marker_value=${row[12]}" >> $PROJECTID/metabarcode_loci_min_merge_length.txt

            # Update $unique_values key with standard marker value
            old_value="${unique_values[$key]}"
            unset "unique_values[$key]"
            unique_values[$marker_value]=$old_value
        fi
    done
done < <(tail -n +2 "$PROJECTID/eDNAExplorerPrimers.csv" | tr -d '\r')


# save QC files to project folder
aws s3 cp $PROJECTID/forward_primers.txt s3://ednaexplorer/projects/${PROJECTID}/QC/forward_primers.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp $PROJECTID/reverse_primers.txt s3://ednaexplorer/projects/${PROJECTID}/QC/reverse_primers.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp $PROJECTID/metabarcode_loci_min_merge_length.txt s3://ednaexplorer/projects/${PROJECTID}/QC/metabarcode_loci_min_merge_length.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# add QC ben jobs
#TODO: switch from crux to qc image
while IFS="," read -ra row; do
    marker_value="${row[1]}"
    if [[ -n "$marker_value" && "${unique_values[$marker_value]}" = "${row[2]} ${row[3]}" ]]; then
        job=$PROJECTID-QC-$marker_value
        $BENPATH add -s $BENSERVER -c " docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -v /tmp:/tmp -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION -e AWS_S3_ACCESS_KEY_ID=$AWS_S3_ACCESS_KEY_ID -e AWS_S3_SECRET_ACCESS_KEY=$AWS_S3_SECRET_ACCESS_KEY -e AWS_S3_DEFAULT_REGION=$AWS_S3_DEFAULT_REGION -e AWS_S3_BUCKET=$AWS_S3_BUCKET --name $job /mnt/qc2.sh -i $PROJECTID -p $marker_value -b /tmp/ben-assign" $job -o $OUTPUT
        # remove from hashmap
        unset "unique_values[$marker_value]"
    fi
done < <(tail -n +2 "$PROJECTID/eDNAExplorerPrimers.csv" | tr -d '\r')

# log PROJECT ID
echo "$PROJECTID" >> $PROJECTID_LOG

# create json of missing markers
missing_markers=()
for marker in "${!unique_values[@]}"; do
    missing_markers+=("$marker")
done

# Convert the keys array to a JSON string
json_data='{"missing_markers":'"$(printf '%s\n' "${missing_markers[@]}" | jq -R -s -c 'split("\n")[:-1]')"'}'
echo "$json_data" > $MISSINGMARKERS

# cleanup
rm -r $PROJECTID