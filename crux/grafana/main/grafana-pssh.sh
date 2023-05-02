#! /bin/bash

while getopts "h:u:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
    esac
done

parallel-ssh -i -t 0 -h $HOSTNAME "sudo apt-get update -y && sudo apt-get upgrade -y"

parallel-scp -h $HOSTNAME prometheus.service /home/$USER/prometheus.service

parallel-scp -h $HOSTNAME prometheus.yml /home/$USER/prometheus.yml

parallel-scp -h $HOSTNAME node_exporter.service /home/$USER/node_exporter.service

parallel-scp -h $HOSTNAME grafana_setup.sh /home/$USER/grafana_setup.sh

parallel-ssh -i -t 0 -h $HOSTNAME "/bin/bash ./grafana_setup.sh"