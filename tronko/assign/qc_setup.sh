#! /bin/bash
set -x

OUTPUT="/etc/ben/output"
while getopts "p:b:k:s:r:" opt; do
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
    esac
done

export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

# make project folder
mkdir $PROJECTID

# touch files
touch $PROJECTID/forwards_primers.txt
touch $PROJECTID/reverse_primers.txt
touch $PROJECTID/metabarcode_loci_min_merge_length.txt

# download metadata file
aws s3 sync s3://ednaexplorer/projects/${PROJECTID}/InputMetadata.csv ${PROJECTID}/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
# download primer master sheet
aws s3 sync s3://ednaexplorer/misc/eDNAExplorerPrimers.csv ${PROJECTID}/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# Read the header row and split it into an array
IFS="," read -ra headers < "$PROJECTID/InputMetadata.csv"

# Loop through the headers and find the positions of columns matching the pattern "Marker_N"
marker_positions=()
for i in "${!headers[@]}"; do
    if [[ "${headers[$i]}" =~ ^Marker\ [0-9]+$ ]]; then
        marker_positions+=("$i")
    fi
done

echo "Positions of columns matching 'Marker_N': ${marker_positions[@]}"

# Create an associative array (hash map) to store unique Marker and their corresponding FP and RP columns
declare -A unique_values

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
done < <(tail -n +2 "$PROJECTID/InputMetadata.csv" | tr -d '\r')

# Print the unique Markers and their corresponding FP and RP columns
for value in "${!unique_values[@]}"; do
    echo "Unique Marker: $value"
    echo "Forward and Reverse Primers: ${unique_values[$value]}"
    echo "--------------------"
done

# Loop through eDNAExplorerPrimers file and check if the Marker ID and FP/RP columns appear in the same row
while IFS="," read -ra row; do
    marker_value="${row[1]}"
    if [[ -n "$marker_value" && "${unique_values[$marker_value]}" = "${row[2]} ${row[3]}" ]]; then
        echo "Unique marker '$marker_value' and its corresponding primers appear in eDNAExplorerPrimers.csv"

        # Add Primer for QC
        echo ">$marker_value" >> $PROJECTID/forwards_primers.txt
        echo "${row[2]}" >> $PROJECTID/forwards_primers.txt

        echo ">$marker_value" >> $PROJECTID/reverse_primers.txt
        echo "${row[3]}" >> $PROJECTID/reverse_primers.txt

        echo "LENGTH_$marker_value=${row[12]}" >> $PROJECTID/metabarcode_loci_min_merge_length.txt
    else
        echo "Unique marker '$marker_value' and its corresponding primers do not appear in eDNAExplorerPrimers.csv"
    fi
done < <(tail -n +2 "$PROJECTID/eDNAExplorerPrimers.csv" | tr -d '\r')


# save QC files to project folder
aws s3 cp $PROJECTID/forward_primers.txt s3://ednaexplorer/projects/${PROJECTID}/QC/forward_primers.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp $PROJECTID/reverse_primers.txt s3://ednaexplorer/projects/${PROJECTID}/QC/reverse_primers.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp $PROJECTID/metabarcode_loci_min_merge_length.txt s3://ednaexplorer/projects/${PROJECTID}/QC/metabarcode_loci_min_merge_length.txt --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# add QC ben jobs
while IFS="," read -ra row; do
    marker_value="${row[1]}"
    if [[ -n "$marker_value" && "${unique_values[$marker_value]}" = "${row[2]} ${row[3]}" ]]; then
        job=$PROJECTID-QC-$marker_value
        ben add -s $BENSERVER -c "cd crux; docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $job crux /mnt/qc.sh -i $PROJECTID -p $marker_value" $job -o $OUTPUT
    fi
done < <(tail -n +2 "$PROJECTID/eDNAExplorerPrimers.csv" | tr -d '\r')