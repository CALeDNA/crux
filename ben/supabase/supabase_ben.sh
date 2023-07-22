#! /bin/bash

# - get job queues txt file
# - run supabase_ben.py
# - upload logs & cleanup ben list
SERVERS=("/tmp/ben-ecopcr" "/tmp/ben-blast" "/tmp/ben-ac" "/tmp/ben-newick" "/tmp/ben-tronko" "/tmp/ben-qc" "/tmp/ben-assign") 

supabase() {
    local server=$1 # /tmp/ben-ecopcr
    local BEN=/etc/ben/ben

    if $BEN list -s $server > tmp; then
      # update supabase SchedulerJobs
      python3 supabase_ben.py tmp $server
      # on finished jobs: upload logs and rm from ben list
      job_type=$(echo "$server" | awk -F- '{print $NF}') # "/tmp/ben-qc" -> "qc"
      header_skipped=false
      while IFS= read -r line
      do
          # skip header
          if ! $header_skipped; then
              header_skipped=true
              continue
          fi
          read -ra columns <<< "$line"
          num_columns=${#columns[@]}
          echo "$num_columns"
          if ((num_columns >= 4)); then
              status="${columns[3]}"
              echo "Status: $status"
              if [ "$status" = "." ]; then
                  # upload log
                  log="${columns[1]}/${columns[2]}.log"
                  out="${columns[1]}/${columns[2]}.out"
                  if [[ "$job_type" == "ecopcr" || "$job_type" == "blast" ]]; then
                      RUNID=$(echo "${columns[2]}" | rev | cut -d'-' -f1-3 | rev) # parse date
                      PRIMER=$(echo "${columns[2]}" | cut -d'-' -f1)
                      aws s3 cp $log s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/$job_type/logs/$(basename $log) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                      aws s3 cp $out s3://ednaexplorer/CruxV2/$RUNID/$PRIMER/$job_type/logs/$(basename $out) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                  elif [[ "$job_type" == "assign" || "$job_type" == "qc" ]]; then
                      if [[ "$job_type" == "qc" ]]; then
                        job_type="QC"
                      fi
                      PROJECTID=$(echo "${columns[2]}" | egrep -o ".*(-assign-|-QC-)" | sed 's/-assign-//; s/-QC-//')
                      PRIMER=${columns[2]#$PROJECTID-assign-}
                      PRIMER=$(echo "$PRIMER" | rev | cut -d'_' -f2- | rev)
                      aws s3 cp $log s3://ednaexplorer/projects/$PROJECTID/$job_type/$PRIMER/logs/$(basename $log) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                      aws s3 cp $out s3://ednaexplorer/projects/$PROJECTID/$job_type/$PRIMER/logs/$(basename $out) --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
                  elif [[ "$job_type" == "ac" || "$job_type" == "newick" || "$job_type" == "tronko" ]]; then
                      echo "placeholder" #TODO
                  fi
                  # remove logs
                  rm $log $out
                  # remove finished job from ben queue
                  $BEN rm "${columns[0]}" -s $server
              fi
          else
              # queued jobs. exit
              break
          fi
      done < tmp
      # cleanup
      rm tmp
    else
      echo "Error occurred while executing: $BEN list -s $server > tmp"
    fi
}

# Iterate over $SERVERS list
for server in "${SERVERS[@]}"; do
  supabase "$server"
done