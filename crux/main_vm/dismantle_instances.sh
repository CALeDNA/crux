#!/bin/bash

OS_USERNAME=""
APIKEY=""
JSCRED=""
NUMINSTANCES=""
HOSTNAME=""
VMNAME="chunk"
VMNUMBER=0
while getopts "j:n:h:m:b:" opt; do
    case $opt in
        j) JSCRED="$OPTARG"
        ;;
        n) NUMINSTANCES="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        m) VMNAME="$OPTARG"
        ;;
        b) VMNUMBER="$OPTARG"
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${JSCRED} && ! -z ${NUMINSTANCES} && ! -z ${HOSTNAME} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -u -k -j -n and -h"
  echo ""
  exit
fi

START=$VMNUMBER
END=$(( VMNUMBER + NUMINSTANCES))

source ${JSCRED}

# delete each instance
for (( c=$START; c<$END; c++ ))
do
    # get chunk num
    chunk=$(printf '%02d' "$c")
    # get corresponding ip address
    let "line=c+1"
    ip_address=$(head -$line ${HOSTNAME} | tail -1)
    # remove IP from instance
    openstack server remove floating ip ${VMNAME}${chunk} ${ip_address}
    # delete IP
    openstack floating ip delete ${ip_address}
    # get volume id
    volumeid=$(openstack server show ${VMNAME}${chunk} -f json | jq .volumes_attached[].id | tr -d '"')
    # delete instance
    openstack server delete ${VMNAME}${chunk} --wait
    # delete volume
    if [[  ${volumeid} != "null" ]]
    then
        openstack volume delete ${volumeid}
    fi
    
done

rm ${HOSTNAME}

