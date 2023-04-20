#!/bin/bash

OS_USERNAME=""
APIKEY=""
JSCRED=""
NUMINSTANCES=""
HOSTNAME=""
NAME=""
while getopts "j:n:h:m:c:" opt; do
    case $opt in
        j) JSCRED="$OPTARG"
        ;;
        n) NUMINSTANCES="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        m) NAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG" # SSH config file: /home/ubuntu/.ssh/config
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${JSCRED} && ! -z ${NUMINSTANCES} && ! -z ${HOSTNAME} && ! -z ${NAME} && ! -z ${CONFIG} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -j -n -h -m and -c"
  echo ""
  exit
fi

source ${JSCRED}

# get corresponding ip address
ip_address=$(grep -A 5 $NAME $CONFIG | grep "HostName" | awk '{print $2}')
# remove IP from instance
openstack server remove floating ip ${VMNAME}${chunk} ${ip_address}
# delete IP
openstack floating ip delete ${ip_address}
# get volume id
volumeid=$(openstack server show $NAME -f json | jq .volumes_attached[].id | tr -d '"')
# delete instance
openstack server delete $NAME --wait
# delete volume
if [[  ${volumeid} != "null" ]]
then
    openstack volume delete $volumeid
fi

#remove $NAME from $HOSTNAME
grep -i -v $NAME $HOSTNAME

# remove $NAME entry from $CONFIG
grep -i -v -A 5 $NAME $CONFIG