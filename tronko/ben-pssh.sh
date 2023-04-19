#! /bin/bash

while getopts "h:c:p:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        p) PKEY="$OPTARG"
        ;;
    esac
done

# copy ssh files
parallel-scp -h $HOSTNAME $CONFIG ./.ssh/config

parallel-scp -h $HOSTNAME $PKEY $PKEY

parallel-ssh -i -h $HOSTNAME "chmod 700 ./.ssh; chmod 600 ./.ssh/*"
