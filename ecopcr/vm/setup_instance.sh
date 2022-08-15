#!/bin/bash

OS_USERNAME=""
FLAVOR=""
IMAGE=""
APIKEY=""
JSCRED=""
NUMINSTANCES=""
SECURITY=""

while getopts "u:f:i:k:j:n:s:" opt; do
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


# PART 1: create security group and add rules to the group
#echo "PART 1: create security group and add rules to the group"
# create group
#openstack security group create --description "ssh & icmp enabled" ${OS_USERNAME}-global-ssh
# create rule to allow ssh
#openstack security group rule create --protocol tcp --dst-port 22:22 --remote-ip 0.0.0.0/0 ${OS_USERNAME}-global-ssh
# create rule to allow ping and other ICMP packets
#openstack security group rule create --proto icmp ${OS_USERNAME}-global-ssh


# PART 2: create an SSH Key and upload to OpenStack
# # create the ssh key
#ssh-keygen -b 2048 -t rsa -f ${APIKEY}
# upload to OpenStack
#openstack keypair create --public-key ${APIKEY}.pub ${APIKEY}


# PART 4: create and start an instance
echo "create VMs"
for (( c=0; c<$NUMINSTANCES; c++ ))
do
    chunk=$(printf '%02d' "$c")
    # create an instance
    openstack server create chunk${chunk} \
    --flavor ${FLAVOR} \
    --image ${IMAGE} \
    --key-name ${APIKEY} \
    --security-group ${SECURITY} \
    --nic net-id=ef65cd35-08de-4d4c-a664-e9b1aed32793 \
    --wait
done
# if error try: ssh-keygen -R <host>
echo "create and add floating ip's"
for (( c=0; c<$NUMINSTANCES; c++ ))
do
    chunk=$(printf '%02d' "$c")
    # create an IP address and save it
    ip_address=$(openstack floating ip create -f json public | jq '.floating_ip_address' | tr -d '"')
    echo "${ip_address}" >> hostnames
    # add ip to instance
    openstack server add floating ip chunk${chunk} ${ip_address}
done

