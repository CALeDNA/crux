#! /bin/bash

set -x

CONFIG=""
while getopts "c:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
    esac
done

source ${CONFIG}

# links step used in ecopcr
# split urls into folders
aws s3 cp s3://ednaexplorer/crux/${LINKS} . --endpoint-url https://js2.jetstream-cloud.org:8001/
# gocmd get -c ${CYVERSE} ${CYVERSE_BASE}/${LINKS} .
python3 split.py --chunks ${NUMINSTANCES} --cores ${THREADS} --input ${LINKS} --output ${RUNID}
aws s3 sync ${RUNID} s3://ednaexplorer/crux/${RUNID}/urls --endpoint-url https://js2.jetstream-cloud.org:8001/
# for i in {1..5}; do gocmd put -c ${CYVERSE} ${RUNID}/* ${CYVERSE_BASE}/${RUNID}/urls/ && echo "Successful gocmd upload" && break || sleep 15; done
rm -r ${RUNID} ${LINKS}

# create VMs
if [[ ${VOLUME} -eq 0 ]]; then
    ./setup_instance.sh -u ${OS_USERNAME} -f ${FLAVOR} -i ${IMAGE} -k ${APIKEY} -j ${JSCRED} -n ${NUMINSTANCES} -s ${SECURITY} -w ${SWAP}
else
    ./setup_instance.sh -u ${OS_USERNAME} -f ${FLAVOR} -i ${IMAGE} -k ${APIKEY} -j ${JSCRED} -n ${NUMINSTANCES} -s ${SECURITY} -v ${VOLUME} -w ${SWAP}
fi

rm ${CYVERSE} ${CONFIG}