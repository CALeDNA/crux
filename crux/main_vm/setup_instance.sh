#!/bin/bash

OS_USERNAME=""
FLAVOR=""
IMAGE=""
APIKEY=""
JSCRED=""
NUMINSTANCES=""
SECURITY=""
VOLUME=""

while getopts "u:f:i:k:j:n:s:v:" opt; do
    case $opt in
        u) OS_USERNAME="$OPTARG"
        ;;
        f) FLAVOR="$OPTARG"
        ;;
        i) IMAGE="$OPTARG"
        ;;
        k) APIKEY="$OPTARG"
        ;;
        j) JSCRED="$OPTARG"
        ;;
        n) NUMINSTANCES="$OPTARG"
        ;;
        s) SECURITY="$OPTARG"
        ;;
        v) VOLUME="$OPTARG"
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${OS_USERNAME} && ! -z ${FLAVOR} && ! -z ${IMAGE} && ! -z ${APIKEY} && ! -z ${JSCRED} && ! -z ${NUMINSTANCES} && ! -z ${SECURITY} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -u -f -i -k -j -n and -s"
  echo ""
  exit
fi

# # username
# OS_USERNAME="hbaez"
# #flavor
# FLAVOR="m3.tiny" # cli: openstack flavor list
# IMAGE="Featured-Ubuntu20" # cli: openstack image list --limit 500
# APIKEY="${OS_USERNAME}-api-key"

# include your Jetstream credentials openrc file
# https://github.com/jetstream-cloud/js2docs/blob/main/docs/ui/cli/openrc.md
# JSCRED="app-cred-docker-cli-auth-openrc.sh"
source ${JSCRED}


# PART 2: create an SSH Key and upload to OpenStack
# # create the ssh key
#ssh-keygen -b 2048 -t rsa -f ${APIKEY}
# upload to OpenStack
#openstack keypair create --public-key ${APIKEY}.pub ${APIKEY}


# create and start an instance
echo "create VMs"
for (( c=0; c<$NUMINSTANCES; c++ ))
do
    chunk=$(printf '%02d' "$c")
    if [[ ! -z ${VOLUME} ]]
        then
            echo "creating VM with ${VOLUME}GB root disk"
            # create an instance
            openstack server create chunk${chunk} \
            --flavor ${FLAVOR} \
            --image ${IMAGE} \
            --key-name ${APIKEY} \
            --security-group ${SECURITY} \
            --nic net-id=ef65cd35-08de-4d4c-a664-e9b1aed32793 \
            --boot-from-volume ${VOLUME} \
            --wait
        else
            echo "creating VM with default root disk size"
            # create an instance
            openstack server create chunk${chunk} \
            --flavor ${FLAVOR} \
            --image ${IMAGE} \
            --key-name ${APIKEY} \
            --security-group ${SECURITY} \
            --nic net-id=ef65cd35-08de-4d4c-a664-e9b1aed32793 \
            --wait
    fi
done
# if error try: ssh-keygen -R <host>
echo "create and add floating ip's"
for (( c=0; c<$NUMINSTANCES; c++ ))
do
    chunk=$(printf '%02d' "$c")
    # create an IP address and save it
    ip_address=$(openstack floating ip create -f json public | jq '.floating_ip_address' | tr -d '"')
    echo "${ip_address}"
    echo "${ip_address}" >> hostnames
    # add ip to instance
    openstack server add floating ip chunk${chunk} ${ip_address}
done