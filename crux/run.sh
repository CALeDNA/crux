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
gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}
gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/urls
gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/ecopcr
gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/bwa-index
gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/bwa-mem
gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/fa-taxid
gocmd -c ${VARS}/${CYVERSE} mkdir ${CYVERSE_BASE}/${RUNID}/logs

# step 1: split urls and create VMs
./run_scheduler.sh -c ${CONFIG}
# docker run run_scheduler.sh -c ${CONFIG}
# crux.yaml: # of machines, etc
# run_scheduler: split urls, create VMs

# step 2: run parallel script for files setup, docker build, ecopcr run, bwa index/mem, and filter largest seq
time python3 parallel.py --hosts hostnames --user ${OS_USERNAME} --pkey ${APIKEY} --config ${CONFIG} --primers ${PRIMERS} --cyverse ${CYVERSE}

# step 3: combine fa-taxid output files by primer
./comb_fataxid.sh -c ${CONFIG} -v ${VARS}

# step 4: dismantle VMs
./dismantle_instances.sh -j ${JSCRED} -n ${NUMINSTANCES} -h hostnames