#! /bin/bash

while getopts "h:c:p:u:s:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        p) PRIMERS="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        s) START="$OPTARG"
        ;;
    esac
done

sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost

if [ "$(wc -l < tmphost)" -eq 1 ]; then
    host=$(cat tmphost)

    ssh "$host" "git clone -b crux-js2 https://github.com/CALeDNA/crux.git"

    scp "$CONFIG" "$host:/home/$USER/crux/crux/vars/"

    scp "$PRIMERS" "$host:/home/$USER/crux/crux/vars/"

    ssh "$host" "sudo apt install awscli -y"
    
    ssh "$host" "cd crux; docker build -q -t crux ."
else
    parallel-ssh -i -t 0 -h tmphost "git clone -b crux-js2 https://github.com/CALeDNA/crux.git"

    parallel-scp -h tmphost $CONFIG /home/$USER/crux/crux/vars/

    parallel-scp -h tmphost $PRIMERS /home/$USER/crux/crux/vars/

    parallel-ssh -i -t 0 -h tmphost "sudo apt install awscli -y"

    parallel-ssh -i -t 0 -h tmphost "cd crux; docker build -q -t crux ."
fi

rm tmphost