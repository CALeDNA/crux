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

# parallel-ssh -i -t 0 -h $HOSTNAME "sudo apt-get update -y && sudo apt-get upgrade -y"

parallel-ssh -i -t 0 -h $HOSTNAME "sudo apt install pandoc -y"

parallel-ssh -i -t 0 -h $HOSTNAME "wget https://www.poirrier.ca/ben/ben-$BEN_VERSION.tar.gz"

parallel-ssh -i -t 0 -h $HOSTNAME "tar -xf ben-$BEN_VERSION.tar.gz"

parallel-ssh -i -t 0 -h $HOSTNAME "cd ben && make && sudo mkdir -p /etc/ben && sudo mv ben /etc/ben/ben"

# Handling single host
if [ "$(wc -l <<< "$HOSTNAME")" -eq 1 ]; then
    host=$(cat "$HOSTNAME")

    scp "$PKEY" ~/.ssh/"$PKEY"

    scp "$CONFIG" ~/.ssh/"$CONFIG"

    ssh -t "$host" "chmod 700 ~/.ssh && chmod 600 ~/.ssh/* && sudo chown -R ubuntu:ubuntu /etc/ben && exit"
else
    parallel-scp -h "$HOSTNAME" "$PKEY" ~/.ssh/"$PKEY"

    parallel-scp -h "$HOSTNAME" "$CONFIG" ~/.ssh/"$CONFIG"
    
    parallel-ssh -i -t 0 -h "$HOSTNAME" "chmod 700 ~/.ssh && chmod 600 ~/.ssh/* && sudo chown -R ubuntu:ubuntu /etc/ben"
fi