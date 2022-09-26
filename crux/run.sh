#! /bin/bash

RUNID=""
CONFIG=""
VARS="vars"
while getopts "i:c:v:" opt; do
    case $opt in
        i) RUNID="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        v) VARS="$OPTARG"
        ;;
    esac
done

source ${VARS}/${CONFIG}


# step 1: split urls and create VMs
./run_scheduler.sh -c ${CONFIG}
# docker run run_scheduler.sh -c ${CONFIG}
# crux.yaml: # of machines, etc
# run_scheduler: split urls, create VMs

# step 2: run parallel script for files setup, docker build, ecopcr run, bwa index/mem, and filter largest seq
time python3 parallel.py --hosts hostnames --user ubuntu --pkey hbaez-api-key --config ${CONFIG} --primers ${PRIMERS} --cyverse ${CYVERSE}

