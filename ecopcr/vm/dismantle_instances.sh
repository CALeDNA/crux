#!/bin/bash

OS_USERNAME=""
APIKEY=""
JSCRED="a"
NUMINSTANCES=""
HOSTNAME=""

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
if [[ ! -z ${OS_USERNAME} && ! -z ${APIKEY} && ! -z ${JSCRED} && ! -z ${NUMINSTANCES} && ! -z ${HOSTNAME} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -u -k -j -n and -h"
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
    openstack server delete chunk${chunk} --wait
done

# delete the security group
#openstack security group delete ${OS_USERNAME}-global-ssh
# delete api key
#openstack keypair delete ${OS_USERNAME}-api-key
# delete hostnames file

rm hostnames

