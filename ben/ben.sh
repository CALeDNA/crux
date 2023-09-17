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
VMNUMBER=0
while getopts "h:c:s:n:m:u:e:p:b:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        s) START="$OPTARG"
        ;;
        n) NODES="$OPTARG"
        ;;
        m) NAME="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        e) BENSERVER="$OPTARG"
        ;;
        p) PKEY="$OPTARG" # assumes file name, not path
        ;;
        b) VMNUMBER="$OPTARG"
        ;;
    esac
done

declare -A SERVER_MAP

SERVER_MAP=(
    ["/tmp/ben-ecopcr"]="/tmp/ben-blast"
    ["/tmp/ben-blast"]="/tmp/ben-ac"
    ["/tmp/ben-ac"]="/tmp/ben-newick"
    ["/tmp/ben-newick"]="/tmp/ben-tronko"
)

# create client config file
echo "Host main" >> $CLIENT_CONFIG
echo "HostName $(curl ifconfig.me)" >> $CLIENT_CONFIG
echo "User ubuntu" >> $CLIENT_CONFIG
echo "PubKeyAuthentication yes" >> $CLIENT_CONFIG
echo "IdentityFile /home/ubuntu/.ssh/$PKEY" >> $CLIENT_CONFIG
echo "IdentitiesOnly yes" >> $CLIENT_CONFIG
echo "StrictHostKeyChecking accept-new" >> $CLIENT_CONFIG
echo "" >> $CLIENT_CONFIG

# make tmp hosts file for parallel-ssh script. only lines after $START
sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost

# setup ben in client VMs
./ben-pssh.sh -h tmphost -p $PKEY -c $CLIENT_CONFIG

if [ $START -gt 0 ]; then
    hostnames=$(cat tmphost)
else
    hostnames=$(cat $HOSTNAME)
fi

counter=$VMNUMBER
for line in $hostnames
do
    counter=$(printf '%02d' $counter)
    host="$NAME$counter"
    /etc/ben/ben client -r $host -n $NODES --remote-path $REMOTE_PATH -s $BENSERVER --remote-socket $BENSERVER -d
    if [[ -v SERVER_MAP[${BENSERVER}] ]]; then
        # add socket connection to add job after
        BENSERVERSECOND="${SERVER_MAP[${BENSERVER}]}"
        /etc/ben/ben client -r $host -n 0 --remote-path $REMOTE_PATH -s $BENSERVERSECOND --remote-socket $BENSERVERSECOND -d
    fi
    counter=$(( 10#$counter + 1 ))
done

rm tmphost $CLIENT_CONFIG