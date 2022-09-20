#! /bin/bash

while getopts "i:" opt; do
    case $opt in
        i) RUNID="$OPTARG"
        ;;
    esac
done

HOSTNAME=$(hostname | tr -dc '0-9')
# # step 1:
# docker run run_scheduler.sh -c crux.yaml
# # crux.yaml: # of machines, etc
# # run_scheduler: split urls, create VMs

# step 1: build docker container
docker build -t crux .

# step 2: run ecopcr inside docker container
docker run -t -v $(pwd)/app/ecopcr:/mnt --name ecopcr crux /mnt/run_ecopcr.sh -c crux_vars.sh -h ${HOSTNAME}

# step 3: run bwa inside docker container
docker run -t -v $(pwd)/app/bwa:/mnt --name bwa crux /mnt/run_bwa.sh -c crux_vars.sh -h ${HOSTNAME}

# step 4: get largest sequence per accid
docker run -t -v $(pwd)/app/taxfilter:/mnt --name taxfilter crux /mnt/get-largest.sh -c crux_vars.sh -h ${HOSTNAME}

# step 5: run tronko
# docker run tronko.sh
