#! /bin/bash

set -x

CONFIG="/home/ubuntu/.ssh/config"
USER="ubuntu"
PKEY="/home/ubuntu/.ssh/hbaez-private-key"
REMOTE_PATH=/etc/ben/ben
START=0
NODES=4
NAME="chunk"
CLIENT_CONFIG="config"
BENSERVER=/tmp/ben-ubuntu
while getopts "h:s:n:m:b:p:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        s) START="$OPTARG"
        ;;
        n) NODES="$OPTARG"
        ;;
        m) NAME="$OPTARG"
        ;;
        b) BENSERVER="$OPTARG"
        ;;
        p) PKEY="$OPTARG"
        ;;
    esac
done

# create client config file
echo "Host main" >> $CLIENT_CONFIG
echo "HostName $(curl ifconfig.me)" >> $CLIENT_CONFIG
echo "User $USER" >> $CLIENT_CONFIG
echo "PubKeyAuthentication yes" >> $CLIENT_CONFIG
echo "IdentityFile $PKEY" >> $CLIENT_CONFIG
echo "IdentitiesOnly yes" >> $CLIENT_CONFIG
echo "StrictHostKeyChecking accept-new" >> $CLIENT_CONFIG
echo "" >> $CLIENT_CONFIG

# make tmp hosts file for parallel-ssh script. only lines after $START
sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost

# setup ben in client VMs
./ben-pssh.sh -h tmphost -p $PKEY -c $CLIENT_CONFIG

rm $CLIENT_CONFIG

if [ $START > 0 ]; then
    hostnames=$(cat tmphost)
else
    hostnames=$(cat $HOSTNAME)
fi

counter=0
for line in $hostnames
do
    counter=$(printf '%02d' $counter)
    host="$NAME$counter"
    ben client -r $host -n $NODES --remote-path $REMOTE_PATH -s $BENSERVER -d
    counter=$(( 10#$counter + 1 ))
done

rm tmphost