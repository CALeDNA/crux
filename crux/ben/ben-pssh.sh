#! /bin/bash
BEN_VERSION='2.12'

while getopts "h:u:b:p:c:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        b) BENSERVER="$OPTARG"
        ;;
        p) PKEY="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
    esac
done

parallel-ssh -i -t 0 -h $HOSTNAME "sudo apt-get update -y && sudo apt-get upgrade -y"

parallel-ssh -i -t 0 -h $HOSTNAME "sudo apt install pandoc -y"

parallel-ssh -i -t 0 -h $HOSTNAME "wget https://www.poirrier.ca/ben/ben-$BEN_VERSION.tar.gz"

parallel-ssh -i -t 0 -h $HOSTNAME "tar -xf ben-$BEN_VERSION.tar.gz"

parallel-ssh -i -t 0 -h $HOSTNAME "cd ben && make && sudo mkdir -p /etc/ben && sudo mv ben /etc/ben/ben"

parallel-scp -h $HOSTNAME ~/.ssh/$PKEY ~/.ssh/$PKEY

parallel-scp -h $HOSTNAME $CONFIG ~/.ssh/$CONFIG

parallel-ssh -i -t 0 -h $HOSTNAME "chmod 700 ~/.ssh && chmod 600 ~/.ssh/*"

parallel-ssh -i -t 0 -h $HOSTNAME "sudo chown -R ubuntu:ubuntu /etc/ben"