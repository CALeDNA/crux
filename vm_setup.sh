#! /bin/bash

USER=""
FLAVOR=""
IMAGE=""
PRIVATEKEY=""
JSCRED=""
NUMINSTANCES=0
SECURITY=""
VOLUME=""
VMNAME="chunk"
VMNUMBER=0
PRIMERS=""
START=0
NODES=0
BENSERVER=""
VARS="/home/ubuntu/crux/crux/vars/crux_vars.sh"
DASHBOARD=/var/lib/grafana/dashboards/overview.json
while getopts "u:f:i:k:j:n:m:b:s:w:v:c:p:o:e:" opt; do
    case $opt in
        u) USER="$OPTARG"
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
        p) PRIMERS="$OPTARG"
        ;;
        o) NODES="$OPTARG"
        ;;
        e) BENSERVER="$OPTARG"
        ;;
    esac
done

BASEDIR=$(pwd)

# check if hostnames exists and get length
if [ -f "hostnames" ]; then
    START=$(wc -l < "hostnames")
    echo "Number of lines in hostnames: $line_count"
else
    START=0
    echo "hostnames does not exist in the current directory."
fi


mv hostnames $BASEDIR/crux/main/
cd ./crux/main
# 1) run setup instance
if [[ ! -z ${VOLUME} ]]; then
    ./setup_instance.sh -u $USER -f $FLAVOR -i $IMAGE -k $PRIVATEKEY -j $JSCRED -n $NUMINSTANCES -m $VMNAME -b $VMNUMBER -s $SECURITY -w $NETWORK -v $VOLUME -c $CONFIG
else
    ./setup_instance.sh -u $USER -f $FLAVOR -i $IMAGE -k $PRIVATEKEY -j $JSCRED -n $NUMINSTANCES -m $VMNAME -b $VMNUMBER -s $SECURITY -w $NETWORK -c $CONFIG
fi

pssh_command="./crux-pssh.sh -h $hostnames -c $VARS -u $USER -s $START"
# 2) setup docker images on client VMs
if [[ $FLAVOR == "m3.xl" ]]; then
    pssh_command="$pssh_command -a"
fi
if [[ $BENSERVER == *"-qc" ]]; then
    pssh_command="$pssh_command -q"
fi
eval "$pssh_command"

mv hostnames $BASEDIR/grafana/main
cd $BASEDIR/grafana/main
# 3) setup grafana
# updates datasources.yaml and grafana overview dashboard with new VMs
./grafana.sh -h hostnames -u $USER -s $START -n $VMNAME -b $VMNUMBER

mv hostnames $BASEDIR/ben
cd $BASEDIR/ben
# 4) setup ben
./ben.sh -h hostnames -c $CONFIG -s $START -n $NODES -m $VMNAME -u $USER -e $BENSERVER -b $VMNUMBER

# move files back to basedir
mv hostnames $BASEDIR

cd $BASEDIR/grafana/main
# update ben panels in grafana
sudo python3 ben-dashboard-mod.py --dashboard $DASHBOARD