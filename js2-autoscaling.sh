#! /bin/bash

USER="ubuntu"
QC="FALSE"
ASSIGN="FALSE"
BENPATH="/etc/ben/ben"
SCALE_DOWN="FALSE"
MAX_VM="0"
while getopts "b:c:d" opt; do
    case $opt in
        b) BENSERVER="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        d) SCALE_DOWN="TRUE"
        ;;
    esac
done

source $CONFIG
# gets JSCRED, SSHKEY, NETWORK, SECURITY
VMNAME="${BENSERVER##*/ben-}"

declare -A MAXVM_MAP

MAXVM_MAP=(
    ["ecopcr"]=$MAX_ECOPCR
    ["blast"]=$MAX_BLAST
    ["ac"]=$MAX_AC
    ["newick"]=$MAX_NEWICK
    ["tronko"]=$MAX_TRONKO
    ["qc"]=$MAX_QC
    ["assign"]=$MAX_ASSIGN
)

MAXVM="${MAXVM_MAP[${VMNAME}]}"

getB() {
    local name=$1
    local hostname=$2
    local b="0"

    numbers=($(grep "$name" "$hostname" | sed "s/$name\([0-9]\+\)/\1/g"))
    if [ ${#numbers[@]} -eq 0 ]; then
        echo "$b"
    else
        # find max number
        max_number=${numbers[0]}
        for number in "${numbers[@]}"; do
            if (( 10#$number > 10#$max_number )); then
                max_number="$number"
            fi
        done
        b=$((10#$max_number + 1))
        echo "$b"
    fi
}

# automatically scale depending on ben nodes

# 1) get triggered by node_util if running = 0 and size > 0
# 2) check here (just in case) that running = 0 and size > 0 for that ben node
# 3) scale ben node to 0 jobs
# 4) delete server with vm_dismantle.sh


# 5) get triggered by node_util if queued > 0 and ben nodes is empty
# 6) check here that it's true just in case
# 7) run vm_setup.sh to setup a server (should test with max 1 server)

# NOTE: scale down should only be used with ben-qc and ben-assign for right now
if [ "$SCALE_DOWN" = "TRUE" ]; then
    # check queued jobs is empty
    queuedCount=$($BENPATH list -t p -s $BENSERVER | wc -l)
    queuedCount=$((queuedCount - 1)) # remove header
    if [ "$queuedCount" -eq "0" ]; then
        # loop through ben nodes and dismantle unused servers
        nodes=$($BENPATH nodes -s $BENSERVER | tail -n +2 | head -n -1)
        while IFS=$' ' read -r -a fields; do
            if [ "${#fields[@]}" -ge 3 ]; then # sanity check
                name="${fields[1]}"
                runningJobs="${fields[2]}"
                if [ $runningJobs -eq "0" ]; then # delete $name
                    ./vm_dismantle.sh -j $JSCRED -h $HOSTNAME -m $name -e $BENSERVER -c $SSHCONFIG -d $DATASOURCE
                fi
            else
                echo "Skipping. $name has $runningJobs running job/s"
            fi
        done <<< "$nodes"
    else
        echo "Skipping. $BENSERVER has a pending queue."
    fi
else # Scale Up
    benServerLineCount=$($BENPATH nodes -s $BENSERVER | wc -l)
    benServerLineCount=$((benServerLineCount - 2)) # account for first and last line

    # check ben nodes is less than max and queued > 0
    if [ "$benServerLineCount" -lt "$MAXVM" ]; then
        queuedCount=$($BENPATH list -t p -s $BENSERVER | wc -l)
        queuedCount=$((queuedCount - 1)) # remove header
        if [ "$queuedCount" -gt "0" ]; then
            # calculate b value
            b=$(getB $VMNAME $HOSTNAME)
            n=$((MAXVM - benServerLineCount))
            
            if [ "$queuedCount" -lt "$n" ]; then
                n="$queuedCount"
            fi

            if [[ $BENSERVER == *assign* ]]; then
                FLAVOR="m3.xl" # need more RAM for tronko assign
            fi

            ./vm_setup.sh -u $USER -f $FLAVOR -i $IMAGE -k $SSHKEY -j $JSCRED -n $n -m $VMNAME -b $b -v $VOLUME -s $SECURITY -w $NETWORK -c $SSHCONFIG -o 1 -e $BENSERVER
        else
            echo "Skipping. $BENSERVER has an empty queue."
        fi
    else
        echo "Skipping. $BENSERVER has reached the maximum number of VM's: $MAXVM"
    fi
fi