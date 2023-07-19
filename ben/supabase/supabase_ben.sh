#! /bin/bash

# - get job queues txt file
# - run supabase_ben.py
SERVERS=("/tmp/ben-ecopcr" "/tmp/ben-blast" "/tmp/ben-ac" "/tmp/ben-newick" "/tmp/ben-tronko" "/tmp/ben-qc" "/tmp/ben-assign") 

supabase() {
    local server=$1 # /tmp/ben-ecopcr
    local BEN=/etc/ben/ben

    if $BEN list -s $server > tmp; then
      python3 supabase_ben.py tmp $server
      rm tmp
    else
      echo "Error occurred while executing: $BEN list -s $server > tmp"
    fi
}

# Iterate over $SERVERS list
for server in "${SERVERS[@]}"; do
  supabase "$server"
done