#! /bin/bash

ASSIGN="FALSE"
QC="FALSE"
while getopts "h:c:u:s:aq" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        s) START="$OPTARG"
        ;;
        a) ASSIGN="TRUE"
        ;;
        q) QC="TRUE"
        ;;
    esac
done

source $CONFIG

sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost

if [ "$(wc -l < tmphost)" -eq 1 ]; then
    host=$(cat tmphost)

    if [ "$BRANCH" = "master" ]; then
        ssh "$host" "git clone https://github.com/CALeDNA/crux.git"
    else
        ssh "$host" "git clone -b $BRANCH https://github.com/CALeDNA/crux.git"
    fi

    scp "$CONFIG" "$host:/home/$USER/crux/crux/vars/"

    if [ "$ASSIGN" = "TRUE" ]; then
        scp ./.env $host:/home/$USER/crux/tronko/assign/jwt
    fi

    ssh "$host" "sudo apt install awscli -y"

    if [ "$QC" = "TRUE" ]; then
        ssh "$host" "docker pull hbaez/qc:latest; docker tag hbaez/qc qc"
    else
        ssh "$host" "docker pull hbaez/crux:latest; docker tag hbaez/crux crux"  
    fi
else
    if [ "$ASSIGN" = "TRUE" ]; then
        parallel-scp -h tmphost ./.env /home/$USER/crux/tronko/assign/jwt
    fi

    if [ "$BRANCH" = "master" ]; then
        parallel-ssh -i -t 0 -h tmphost "git clone https://github.com/CALeDNA/crux.git"
    else
        parallel-ssh -i -t 0 -h tmphost "git clone -b $BRANCH https://github.com/CALeDNA/crux.git"
    fi

    parallel-scp -h tmphost $CONFIG /home/$USER/crux/crux/vars/

    parallel-ssh -i -t 0 -h tmphost "sudo apt install awscli -y"

    if [ "$QC" = "TRUE" ]; then
        parallel-ssh -i -t 0 -h tmphost "docker pull hbaez/qc:latest; docker tag hbaez/qc qc"
    else
        parallel-ssh -i -t 0 -h tmphost "docker pull hbaez/crux:latest; docker tag hbaez/crux crux"
    fi
fi

rm tmphost
