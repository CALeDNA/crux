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

# step 1: upload variable files
aws s3 cp ${VARS}/${CONFIG} s3://ednaexplorer/crux/${RUNID}/logs/${CONFIG} --endpoint-url https://js2.jetstream-cloud.org:8001/
aws s3 cp ${VARS}/${PRIMERS} s3://ednaexplorer/crux/${RUNID}/logs/${PRIMERS} --endpoint-url https://js2.jetstream-cloud.org:8001/

# step 2: split urls and create VMs
./run_scheduler.sh -c ${CONFIG}

# step 3: run parallel script for files setup, docker build, ecopcr run, bwa index/mem, and filter largest seq

time python3 parallel.py --hosts hostnames --user ${OS_USERNAME} --pkey ${APIKEY} --config ${CONFIG} --primers ${PRIMERS} --cyverse ${CYVERSE} --aws_key ${AWS_ACCESS_KEY_ID} --aws_secret ${AWS_SECRET_ACCESS_KEY} --aws_region ${AWS_DEFAULT_REGION}

# step 4: dismantle VMs
./dismantle_instances.sh -j ${JSCRED} -n ${NUMINSTANCES} -h hostnames

# step 5: combine fa-taxid output files by primer
./comb_fataxid.sh -c ${CONFIG} -v ${VARS}