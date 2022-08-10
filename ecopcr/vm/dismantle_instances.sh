#!/bin/bash

OS_USERNAME="hbaez"
APIKEY="hbaez-api-key"
JSCRED="app-cred-docker-cli-auth-openrc.sh"
NUMINSTANCES="10"
HOSTNAME="hostnames"

while getopts "u:k:j:n:h:" opt; do
    case $opt in
        u) OS_USERNAME="$OPTARG"
        ;;
        k) APIKEY="$OPTARG"
        ;;
        j) JSCRED="$OPTARG"
        ;;
        n) NUMINSTANCES="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -u ${OS_USERNAME} && ! -k ${APIKEY} && ! -j ${JSCRED} && ! -n ${NUMINSTANCES} && ! -h ${HOSTNAME} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -u -f -i -k -j -n and -h"
  echo ""
  exit
fi


source ${JSCRED}

# delete each instance
for (( c=0; c<$NUMINSTANCES; c++ ))
do
    # get chunk num
    chunk=$(printf '%02d' "$c")
    # get corresponding ip address
    let "line=c+1"
    ip_address=$(head -$line ${HOSTNAME} | tail -1)
    # remove IP from instance
    openstack server remove floating ip chunk${chunk} ${ip_address}
    # delete IP
    openstack floating ip delete ${ip_address}
    # delete instance
    openstack server delete chunk${chunk}
done

# delete the security group
openstack security group delete ${OS_USERNAME}-global-ssh
# delete api key
openstack keypair delete ${OS_USERNAME}-api-key
# delete hostnames file
rm hostnames

