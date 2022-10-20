#! /bin/bash

CONFIG=""
while getopts "c:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
    esac
done

HOSTNAME=$(hostname | tr -dc '0-9');

# run bwa
docker run -t -v $(pwd)/app/bwa:/mnt -v $(pwd)/vars:/vars --name bwa crux /mnt/run_bwa.sh -c ${CONFIG} -h ${HOSTNAME}

# run fa-taxid
docker run -t -v $(pwd)/app/taxfilter:/mnt -v $(pwd)/vars:/vars --name taxfilter crux /mnt/get-largest.sh -c ${CONFIG} -h ${HOSTNAME}

# shutdown instance
sudo shutdown now