#! /bin/bash

CONFIG=""
while getopts "c:" opt; do
    case $opt in
        i) CONFIG="$OPTARG"
        ;;
    esac
done

source ${CONFIG}

# split urls into folders
gocmd get -c ${CYVERSE} /iplant/home/shared/eDNA_Explorer/urls/${LINKS} .
python3 split.py --chunks ${NUMINSTANCES} --cores ${THREADS} --input ${LINKS} --output ${RUNID}
gocmd put -c ${CYVERSE} ${RUNID} /iplant/home/shared/eDNA_Explorer/urls/
rm -r ${RUNID} ${LINKS}

# create VMs
if [[ ${VOLUME} -eq 0 ]]; then
    JS2/setup_instance.sh -u ${OS_USERNAME} -f ${FLAVOR} -i ${IMAGE} -k ${APIKEY} -j ${JSCRED} -n ${NUMINSTANCES} -s ${SECURITY}
else
    JS2/setup_instance.sh -u ${OS_USERNAME} -f ${FLAVOR} -i ${IMAGE} -k ${APIKEY} -j ${JSCRED} -n ${NUMINSTANCES} -s ${SECURITY} -v ${VOLUME}
fi


# run scripts using parallel ssh
python3 parallel.py


# dismantle VMs