#! /bin/bash

while getopts "h:c:p:u:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        p) PRIMERS="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
    esac
done

parallel-ssh -i -t 0 -h $HOSTNAME "git clone -b crux-hector https://github.com/CALeDNA/crux.git"

parallel-scp -h $HOSTNAME $CONFIG /home/$USER/crux/crux/vars/

parallel-scp -h $HOSTNAME $PRIMERS /home/$USER/crux/crux/vars/

parallel-ssh -i -t 0 -h $HOSTNAME "cd crux; docker build -q -t crux ."
