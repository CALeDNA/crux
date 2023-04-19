#! /bin/bash

set -x

CONFIG="/home/ubuntu/.ssh/config"
USER="ubuntu"
hostnames=$(cat hostnames)
PKEY="/home/ubuntu/.ssh/hbaez-private-key"
REMOTE_PATH=/home/${USER}/bin/ben
START=0
NODES=4
NAME="chunk"
CLIENT_CONFIG="config"

while getopts "s:n:m:" opt; do
    case $opt in
        s) START="$OPTARG"
        ;;
        n) NODES="$OPTARG"
        ;;
        m) NAME="$OPTARG"
    esac
done

#TODO: make tmp hosts file for parallel-ssh script. only lines after $START


# create client config file
echo "Host main" >> $CLIENT_CONFIG
echo "HostName $(curl ifconfig.me)" >> $CLIENT_CONFIG
echo "User $USER" >> $CLIENT_CONFIG
echo "PubKeyAuthentication yes" >> $CLIENT_CONFIG
echo "IdentityFile $PKEY" >> $CLIENT_CONFIG
echo "IdentitiesOnly yes" >> $CLIENT_CONFIG
echo "StrictHostKeyChecking accept-new" >> $CLIENT_CONFIG
echo "" >> $CLIENT_CONFIG

# moves ben to clients
./ben-pssh.sh -h "hostnames" $CONFIG -p $PKEY -c $CLIENT_CONFIG

rm $CLIENT_CONFIG

counter=0
for line in $hostnames
do
    if [ $counter -ge $START ]; then
        counter=$(printf '%02d' $counter)
        host="$NAME$counter"
        ben client -r $host -n $NODES --remote-path $REMOTE_PATH -d
        counter=$(( 10#$counter + 1 ))
    fi
done
