#! /bin/bash

ASSIGN="FALSE"
while getopts "h:c:u:s:a" opt; do
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
    esac
done

sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost

if [ "$(wc -l < tmphost)" -eq 1 ]; then
    host=$(cat tmphost)

    ssh "$host" "git clone https://github.com/CALeDNA/crux.git"

    scp "$CONFIG" "$host:/home/$USER/crux/crux/vars/"

    if [ "$ASSIGN" = "TRUE" ]; then
        scp ./.env $host:/home/$USER/crux/tronko/assign/jwt
    fi

    ssh "$host" "sudo apt install awscli -y"

    ssh "$host" "docker pull hbaez/crux:latest; docker tag hbaez/crux crux"
else
    if [ "$ASSIGN" = "TRUE" ]; then
        parallel-scp -h tmphost ./.env /home/$USER/crux/tronko/assign/jwt
    fi
    parallel-ssh -i -t 0 -h tmphost "git clone https://github.com/CALeDNA/crux.git"

    parallel-scp -h tmphost $CONFIG /home/$USER/crux/crux/vars/

    parallel-ssh -i -t 0 -h tmphost "sudo apt install awscli -y"

    parallel-ssh -i -t 0 -h tmphost "docker pull hbaez/crux:latest; docker tag hbaez/crux crux"
fi

rm tmphost
