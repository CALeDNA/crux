#! /bin/bash

# - get job queues txt file
# - run supabase_ben.py
# - upload logs & cleanup ben list
QUEUES=("/etc/ben/queue/ecopcr.ini" "/etc/ben/queue/blast.ini" "/etc/ben/queue/ac.ini" "/etc/ben/queue/newick.ini" "/etc/ben/queue/tronko.ini" "/etc/ben/queue/qc.ini" "/etc/ben/queue/assign.ini")

supabase() {
    local queue=$1 # /etc/ben/queue/ecopcr.ini
    local server=$2
    local BEN=/etc/ben/ben

    # update supabase SchedulerJobs
    python3 supabase_ben.py $queue $server
    # on finished jobs: upload logs and rm from ben list
    job_type=$(echo "$server" | awk -F- '{print $NF}') # "/tmp/ben-qc" -> "qc"
    while IFS= read -r line
    do
        # Check if the line contains "type =" or "id ="
        if [[ "$line" == *"type ="* ]]; then
            current_type=$(echo "$line" | awk -F " = " '{print $2}')
        elif [[ "$line" == *"id ="* && "$line" != *"_id ="* ]]; then
            current_id=$(echo "$line" | awk -F " = " '{print $2}')
        elif [[ "$line" == *"name ="* && "$line" != *"_name ="* ]]; then
            current_job=$(echo "$line" | awk -F " = " '{print $2}')
        elif [[ "$line" == *"stdout_path ="* ]]; then
            current_log_path=$(echo "$line" | awk -F " = " '{print $2}')
            if [ "$current_type" = "done" ]; then
                # delete finished job for queue
                $BEN rm $current_id -s $server
                # upload log to aws s3 bucket
                out=$current_log_path
                log=$(echo "$out" | sed 's/\.out$/.log/')
                if [[ "$job_type" == "ecopcr" || "$job_type" == "blast" ]]; then
                    RUNID=$(echo "$current_job" | rev | cut -d'-' -f1-3 | rev) # parse date
                    PRIMER=$(echo "$current_job" | cut -d'-' -f1)
                    aws s3 cp $log s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/$job_type/logs/$(basename $log) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                    aws s3 cp $out s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/$job_type/logs/$(basename $out) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                elif [[ "$job_type" == "assign" || "$job_type" == "qc" ]]; then
                    if [[ "$job_type" == "qc" ]]; then
                      job_type="QC"
                      PROJECTID=$(echo "$current_job" | egrep -o ".*(-assign-|-QC-)" | sed 's/-assign-//; s/-QC-//')
                      PRIMER="${current_job#*-QC-}"
                    else
                      PROJECTID=$(echo "$current_job" | egrep -o ".*(-assign-|-QC-)" | sed 's/-assign-//; s/-QC-//')
                      PRIMER="${current_job#*-assign-}"
                    fi
                    echo $current_job
                    echo $PROJECTID
                    echo $PRIMER
                    echo $job_type
                    # aws s3 cp $log s3://ednaexplorer/projects/$PROJECTID/$job_type/$PRIMER/logs/$(basename $log) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                    # aws s3 cp $out s3://ednaexplorer/projects/$PROJECTID/$job_type/$PRIMER/logs/$(basename $out) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                elif [[ "$job_type" == "ac" || "$job_type" == "newick" || "$job_type" == "tronko" ]]; then
                    RUNID=$(echo "$current_job" | rev | cut -d'-' -f1-3 | rev) # parse date
                    PRIMER=$(echo "$current_job" | sed "s/\(.*\)-$job_type.*/\1/")
                    if [[ "$job_type" == "ac" ]]; then
                      job_type="ancestralclust"
                    fi
                    aws s3 cp $log s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/$job_type/logs/$(basename $log) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                    aws s3 cp $out s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/$job_type/logs/$(basename $out) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                fi
                # remove logs
                rm $log $out
                # reset variables
                current_type=""
                current_id=""
                current_job=""
                current_log_path=""

            else
                # queued jobs. exit
                break
            fi
        fi
    done < $queue
}

# Iterate over $QUEUES list
for queue in "${QUEUES[@]}"; do
  # run if queue exists
  if [ -f "$queue" ]; then
    # get server socket file
    base_path="${queue##*/}"
    # Remove everything after and including the last dot
    base_name="${base_path%.*}"
    # Replace slashes with dashes
    # new_path="${queue//\//-}"
    # Combine base name and modified path
    server="/tmp/ben-${base_name}"


    supabase "$queue" "$server"
  fi
done