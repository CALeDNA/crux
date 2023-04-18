#!/bin/bash

set -x

OS_USERNAME=""
FLAVOR=""
IMAGE=""
PRIVATEKEY=""
JSCRED=""
NUMINSTANCES=0
SECURITY=""
VOLUME=""
VMNAME="chunk"
VMNUMBER=0
while getopts "u:f:i:k:j:n:m:b:s:w:v:c:" opt; do
    case $opt in
        u) OS_USERNAME="$OPTARG"
        ;;
        f) FLAVOR="$OPTARG"
        ;;
        i) IMAGE="$OPTARG"
        ;;
        k) PRIVATEKEY="$OPTARG"
        ;;
        j) JSCRED="$OPTARG"
        ;;
        n) NUMINSTANCES="$OPTARG"
        ;;
        m) VMNAME="$OPTARG"
        ;;
        b) VMNUMBER="$OPTARG"
        ;;
        s) SECURITY="$OPTARG"
        ;;
        w) NETWORK="$OPTARG"
        ;;
        v) VOLUME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG" # SSH config file: /home/ubuntu/.ssh/config
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${OS_USERNAME} && ! -z ${FLAVOR} && ! -z ${IMAGE} && ! -z ${PRIVATEKEY} && ! -z ${JSCRED} && ! -z ${NUMINSTANCES} && ! -z ${SECURITY} && ! -z ${NETWORK} && ! -z ${CONFIG} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -u -f -i -k -j -n -w -c and -s"
  echo ""
  exit
fi

START=$VMNUMBER
END=$(( VMNUMBER + NUMINSTANCES))

# # username
# OS_USERNAME="ubuntu"
# #flavor
# FLAVOR="m3.tiny" # cli: openstack flavor list
# IMAGE="Featured-Ubuntu20" # cli: openstack image list --limit 500
# PRIVATEKEY="${OS_USERNAME}-private-key"

# include your Jetstream credentials openrc file
# https://github.com/jetstream-cloud/js2docs/blob/main/docs/ui/cli/openrc.md
# JSCRED="app-cred-docker-cli-auth-openrc.sh"
source ${JSCRED}


# PART 2: create an SSH Key and upload to OpenStack
# # create the ssh key
#ssh-keygen -b 2048 -t rsa -f ${PRIVATEKEY}
# upload to OpenStack
#openstack keypair create --public-key ${PRIVATEKEY}.pub ${PRIVATEKEY}


# create and start an instance
echo "create VMs"
for (( c=$START; c<$END; c++ ))
do
    chunk=$(printf '%02d' "$c")
    if [[ ! -z ${VOLUME} ]]
        then
            echo "creating VM with ${VOLUME}GB root disk"
            # create an instance
            openstack server create ${VMNAME}${chunk} \
            --flavor ${FLAVOR} \
            --image ${IMAGE} \
            --key-name ${PRIVATEKEY} \
            --security-group ${SECURITY} \
            --nic net-id=${NETWORK} \
            --boot-from-volume ${VOLUME} \
            --wait
        else
            echo "creating VM with default root disk size"
            # create an instance
            openstack server create ${VMNAME}${chunk} \
            --flavor ${FLAVOR} \
            --image ${IMAGE} \
            --key-name ${PRIVATEKEY} \
            --security-group ${SECURITY} \
            --nic net-id=${NETWORK} \
            --wait
    fi
done

echo "create and add floating ip's"
for (( c=$START; c<$END; c++ ))
do
    chunk=$(printf '%02d' "$c")
    # create an IP address and save it
    ip_address=$(openstack floating ip create -f json public | jq '.floating_ip_address' | tr -d '"')
    echo $ip_address
    # add ip to instance
    openstack server add floating ip ${VMNAME}${chunk} ${ip_address} # || $(sleep 2; openstack server remove floating ip chunk${chunk} ${ip_address}; openstack server add floating ip chunk${chunk} ${ip_address})

    echo "Host $VMNAME$chunk" >> $CONFIG
    echo "HostName $ip_address" >> $CONFIG
    echo "User $OS_USERNAME" >> $CONFIG
    echo "PubKeyAuthentication yes" >> $CONFIG
    echo "IdentityFile $PRIVATEKEY" >> $CONFIG
    echo "IdentitiesOnly yes" >> $CONFIG
    echo "StrictHostKeyChecking accept-new" >> $CONFIG
    echo "" >> $CONFIG

    echo $VMNAME$chunk >> hostnames
    
    sleep 10
done
