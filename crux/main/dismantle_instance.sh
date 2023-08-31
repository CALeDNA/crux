#!/bin/bash

set -x
set -o allexport

OS_USERNAME=""
JSCRED=""
HOSTNAME=""
NAME=""
while getopts "j:h:m:c:d:" opt; do
    case $opt in
        j) JSCRED="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        m) NAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG" # SSH config file: /home/ubuntu/.ssh/config
        ;;
        d) DATASOURCE="$OPTARG"
        ;;
    esac
done

#Check that user has all of the default flags set
if [[ ! -z ${JSCRED} && ! -z ${HOSTNAME} && ! -z ${NAME} && ! -z ${CONFIG} ]];
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

# get volume id
volume_id=$(openstack server show $NAME -c volumes_attached -f json | jq -r .volumes_attached | cut -d"=" -f2 | tr -d "'")
# get corresponding ip address
ip_address=$(grep -A 5 $NAME $CONFIG | grep "HostName" | awk '{print $2}')
# remove IP from instance
openstack server remove floating ip $NAME $ip_address
# delete IP
openstack floating ip delete $ip_address
# delete instance
openstack server delete $NAME --wait
# delete volume
if [[  $volume_id != "null" ]]
then
    openstack volume delete $volume_id
fi

#remove $NAME from $HOSTNAME
# check if hostnames length > 1
line_count=$(wc -l < "$HOSTNAME")
if [ "$line_count" -gt 1 ]; then
    grep -i -v $NAME $HOSTNAME > tmp
    mv tmp $HOSTNAME
else
    rm $HOSTNAME
fi

# remove $NAME entry from $CONFIG
linenumber=$(grep -n $NAME $CONFIG | cut -d":" -f1)
endnumber=$(( $linenumber + 7 ))
sed -i "${linenumber},${endnumber}d" $CONFIG

# remove $NAME from $DATASOURCE
linenumber=$(grep -n "name: $NAME" $DATASOURCE | cut -d":" -f1)
endnumber=$(( $linenumber + 6 ))
sudo sed -i "${linenumber},${endnumber}d" $DATASOURCE
