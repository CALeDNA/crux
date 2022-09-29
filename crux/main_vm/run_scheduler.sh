#! /bin/bash

CONFIG=""
VARS="vars"
while getopts "c:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
    esac
done


cp ${VARS}/* .
# remove forward slash from paths meant for docker
source ${CONFIG}

# split urls into folders
gocmd get -c ${CYVERSE} ${CYVERSE_BASE}/${LINKS} .
python3 split.py --chunks ${NUMINSTANCES} --cores ${THREADS} --input ${LINKS} --output ${RUNID}
gocmd put -c ${CYVERSE} ${RUNID}/* ${CYVERSE_BASE}/${RUNID}/urls/
rm -r ${RUNID} ${LINKS}

# create VMs
if [[ ${VOLUME} -eq 0 ]]; then
    ./setup_instance.sh -u ${OS_USERNAME} -f ${FLAVOR} -i ${IMAGE} -k ${APIKEY} -j ${JSCRED} -n ${NUMINSTANCES} -s ${SECURITY}
else
    ./setup_instance.sh -u ${OS_USERNAME} -f ${FLAVOR} -i ${IMAGE} -k ${APIKEY} -j ${JSCRED} -n ${NUMINSTANCES} -s ${SECURITY} -v ${VOLUME}
fi

rm ${CYVERSE} ${CONFIG} ${PRIMERS}