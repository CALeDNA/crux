#! /bin/bash
set -x
# check if tronko finished for all primers
aws s3 cp s3://ednaexplorer/projects/$PROJECTID/QC/metabarcode_loci_min_merge_length.txt . --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/

# check there's no other running jobs
currentJobs=$(ben list -s /tmp/ben-assign -t r | grep $PROJECTID)
if ["$currentJobs" -eq "1" ]; then 
    primerCount=$(wc -l < metabarcode_loci_min_merge_length.txt)
    primerFolders=$(find $PROJECTID/ -type d | wc -l)
    primerSuccessFolders=$(find $PROJECTID/ -mindepth 2 -type d -exec dirname {} \; | sort | uniq -d | wc -l)
    # Create an array to store the counted folders
    countedFolders=()
    # Find the counted folders and add them to the array
    while read -r countedFolder; do
    countedFolders+=("$countedFolder")
    done < <(find $PROJECTID/ -mindepth 2 -type d -exec dirname {} \; | sort | uniq -d)

    # check all primers made it to assign step
    if [ "$primerCount" -eq "$primerSuccessFolders" ]; then
        # trigger COMPLETE JWT
        python3 jwt/jwt_notif.py --status "COMPLETED" --project "$PROJECTID"
    else
        primersList=""
        for folder in "${countedFolders[@]}"; do
            if [ -n "$primersList" ]; then
                concatenatedFolders+=","  # Add a comma delimiter if the string is not empty
            fi
            primersList+="$folder"  # Concatenate the folder
        done
        python3 jwt/jwt_notif.py --status "PROCESSING_FAILED" --project "$PROJECTID" --primers "$primersList"
    fi
else
    # more tronko jobs running from this project
    echo "Skipping JWT notification. More jobs in queue for $PROJECTID."
fi