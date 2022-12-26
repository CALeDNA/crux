#! /bin/bash

RUNID=""
CONFIG=""
VARS="vars"
while getopts "c:v:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        v) VARS="$OPTARG"
        ;;
    esac
done

source ${VARS}/${CONFIG}

# make cyverse folders
# gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}
# gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/urls
# gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/ecopcr
# gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/bwa-index
# gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/bwa-mem
# gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/fa-taxid
# gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/logs


# step 1: upload variable files
aws s3 cp ${VARS}/${CONFIG} s3://ednaexplorer/crux/${RUNID}/logs/${CONFIG} --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp ${VARS}/${PRIMERS} s3://ednaexplorer/crux/${RUNID}/logs/${PRIMERS} --endpoint-url https://js2.jetstream-cloud.org:8001/

# gocmd -c ${VARS}/${CYVERSE} put ${VARS}/${CONFIG} ${CYVERSE_BASE}/${RUNID}/logs/
# gocmd -c ${VARS}/${CYVERSE} put ${VARS}/${PRIMERS} ${CYVERSE_BASE}/${RUNID}/logs/

# step 2: split urls and create VMs
./run_scheduler.sh -c ${CONFIG}
# docker run run_scheduler.sh -c ${CONFIG}
# crux.yaml: # of machines, etc
# run_scheduler: split urls, create VMs

# step 3: run parallel script for files setup, docker build, ecopcr run, bwa index/mem, and filter largest seq
time python3 parallel.py --hosts hostnames --user ${OS_USERNAME} --pkey ${APIKEY} --config ${CONFIG} --primers ${PRIMERS} --cyverse ${CYVERSE}

# step 4: dismantle VMs
./dismantle_instances.sh -j ${JSCRED} -n ${NUMINSTANCES} -h hostnames

# step 5: combine fa-taxid output files by primer
./comb_fataxid.sh -c ${CONFIG} -v ${VARS}