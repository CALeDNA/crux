#! /bin/bash

while getopts "c:v:" opt; do
    case $opt in
        c) CONFIG="$OPTARG"
        ;;
        v) VARS="$OPTARG"
        ;;
    esac
done

cp ${VARS} .
source ${CONFIG}
FLAVOR="m3.medium"
NAME="main"

# create main VM
openstack server create ${NAME} \
--flavor ${FLAVOR} \
--image ${IMAGE} \
--swap ${SWAP} \
--key-name ${APIKEY} \
--security-group ${SECURITY} \
--nic net-id=ef65cd35-08de-4d4c-a664-e9b1aed32793 \
--wait

# add ip address
ip_address=$(openstack floating ip create -f json public | jq '.floating_ip_address' | tr -d '"')
openstack server add floating ip ${NAME} ${ip_address}

# run main_setup.sh on remote machine
ssh-add ${APIKEY}
ssh -A ubuntu@${ip_address} 'bash -s' main_setup.sh

# run run.sh on main vm
