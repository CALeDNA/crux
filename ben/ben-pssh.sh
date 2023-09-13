#! /bin/bash
BEN_VERSION='2.14'

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

parallel-scp -h $HOSTNAME $PKEY ~/.ssh/$PKEY

parallel-scp -h $HOSTNAME $CONFIG ~/.ssh/$CONFIG

if [ "$(wc -l < $HOSTNAME)" -eq 1 ]; then
    host=$(cat $HOSTNAME)

    ssh "$host" "sudo apt install pandoc -y"

    ssh "$host" "wget https://www.poirrier.ca/ben/ben-$BEN_VERSION.tar.gz"

    ssh "$host" "tar -xf ben-$BEN_VERSION.tar.gz"

    ssh "$host" "cd ben && make && sudo mkdir -p /etc/ben && sudo cp ben /usr/local/bin && sudo mv ben /etc/ben/ben"

    ssh "$host" "chmod 700 ~/.ssh && chmod 600 ~/.ssh/* && sudo chown -R ubuntu:ubuntu /etc/ben"
else
    parallel-ssh -i -t 0 -h $HOSTNAME "sudo apt install pandoc -y"

    parallel-ssh -i -t 0 -h $HOSTNAME "wget https://www.poirrier.ca/ben/ben-$BEN_VERSION.tar.gz"

    parallel-ssh -i -t 0 -h $HOSTNAME "tar -xf ben-$BEN_VERSION.tar.gz"

    parallel-ssh -i -t 0 -h $HOSTNAME "cd ben && make && sudo mkdir -p /etc/ben && sudo cp ben /usr/local/bin && sudo mv ben /etc/ben/ben"

    parallel-ssh -i -t 0 -h $HOSTNAME "chmod 700 ~/.ssh && chmod 600 ~/.ssh/* && sudo chown -R ubuntu:ubuntu /etc/ben"
fi