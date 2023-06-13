#! bin/bash
set -x

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
QC="" # -> is this setup for QC pipeline?
START=0
NODES=0
BENSERVER=""
while getopts "u:f:i:k:j:n:m:b:s:w:v:c:p:qo:e:" opt; do
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
        q) QC="TRUE"
        ;;
        o) NODES="$OPTARG"
        ;;
        e) BENSERVER="$OPTARG"
        ;;
    esac
done

# check if hostnames exists and get length
if [ -f "hostnames" ]; then
    START=$(wc -l < "$filename")
    echo "Number of lines in hostnames: $line_count"
else
    echo "hostnames does not exist in the current directory."
fi

# 1) run setup instance
# creates/appends hostnames file
./crux/main/setup_instance.sh -u $USER -f $FLAVOR -i $IMAGE -k $PRIVATEKEY -j $JSCRED -n $NUMINSTANCES -m $VMNAME -b $VMNUMBER -s $SECURITY -w $NETWORK -v $VOLUME -c $CONFIG

# 2) run docker build
# -q: should run docker for crux or qc pipeline
./crux/main/crux-pssh.sh -h hostnames -c $CONFIG -p $PRIMERS -u $USER -q $QC

# 3) setup grafana
# updates datasources.yaml and grafana overview dashboard with new VMs
./grafana/main/grafana.sh -h hostnames -p $PRIVATEKEY -u $USER -s $START -n $VMNAME

# 4) setup ben
./ben/ben.sh -h hostnames -c $CONFIG -s $START -n $NODES -m $VMNAME -u $USER -b $BENSERVER -p $PRIVATEKEY