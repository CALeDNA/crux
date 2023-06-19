#! /bin/bash
set -x

OUTPUT="/etc/ben/output"
INPUT_METADATA="METABARCODING.csv"
BENPATH="/etc/ben/ben"
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
touch $PROJECTID/forward_primers.txt
touch $PROJECTID/reverse_primers.txt
touch $PROJECTID/metabarcode_loci_min_merge_length.txt

# download metadata file
aws s3 cp s3://ednaexplorer/projects/${PROJECTID}/$INPUT_METADATA ${PROJECTID}/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
# download primer master sheet
aws s3 cp s3://ednaexplorer/CruxV2/eDNAExplorerPrimers.csv ${PROJECTID}/ --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# find header row
line_number=$(grep -n "Sample Type" "$PROJECTID/$INPUT_METADATA" | cut -d ":" -f 1)
# Remove all lines before the line containing "Sample Type"
sed -i "1,$((line_number-1))d" "$PROJECTID/$INPUT_METADATA"

# Read the header row and split it into an array
IFS="," read -ra headers < "$PROJECTID/$INPUT_METADATA"

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
    if [[ -n "$marker_value" && "${unique_values[$marker_value]}" = "${row[2]} ${row[3]}" ]]; then
        echo "Unique marker '$marker_value' and its corresponding primers appear in $INPUT_METADATA"

        # Add Primer for QC
        echo ">$marker_value" >> $PROJECTID/forward_primers.txt
        echo "${row[2]}" >> $PROJECTID/forward_primers.txt

        echo ">$marker_value" >> $PROJECTID/reverse_primers.txt
        echo "${row[3]}" >> $PROJECTID/reverse_primers.txt

        echo "LENGTH_$marker_value=${row[12]}" >> $PROJECTID/metabarcode_loci_min_merge_length.txt
    else
        echo "Unique marker '$marker_value' and its corresponding primers do not appear in $INPUT_METADATA"
    fi
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
        $BENPATH add -s $BENSERVER -c "cd crux/tronko/assign; docker run --rm -t -v ~/crux/tronko/assign:/mnt -v ~/crux/crux/vars:/vars -e AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID -e AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY -e AWS_DEFAULT_REGION=$AWS_DEFAULT_REGION --name $job qc /mnt/qc.sh -i $PROJECTID -p $marker_value -b /tmp/ben-assign" $job -o $OUTPUT
    fi
done < <(tail -n +2 "$PROJECTID/eDNAExplorerPrimers.csv" | tr -d '\r')

# cleanup
rm -r $PROJECTID