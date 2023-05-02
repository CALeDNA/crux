#!/bin/bash
set -x

OS_USERNAME=""
APIKEY=""
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
grep -i -v $NAME $HOSTNAME > tmp && mv tmp $HOSTNAME

# remove $NAME entry from $CONFIG
linenumber=$(grep -n $NAME $CONFIG | cut -d":" -f1)
endnumber=$(( $linenumber + 7 ))
sed -i "${linenumber},${endnumber}d" $CONFIG

# remove $NAME from datasource
linenumber=$(grep -n "name: $NAME" $DATASOURCE | cut -d":" -f1)
endnumber=$(( $linenumber + 6 ))
sudo sed -i "${linenumber},${endnumber}d" $DATASOURCE
