#! /bin/bash

while getopts "h:u:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
    esac
done

parallel-scp -h $HOSTNAME ~/crux/grafana/client/prometheus.service /home/$USER/prometheus.service

parallel-scp -h $HOSTNAME ~/crux/grafana/client/prometheus.yml /home/$USER/prometheus.yml

parallel-scp -h $HOSTNAME ~/crux/grafana/client/node_exporter.service /home/$USER/node_exporter.service

parallel-scp -h $HOSTNAME ~/crux/grafana/client/grafana_setup.sh /home/$USER/grafana_setup.sh

# Handling single host
if [ "$(wc -l <<< "$HOSTNAME")" -eq 1 ]; then
    host=$(cat "$HOSTNAME")
    ssh -t "$host" "/bin/bash ./grafana_setup.sh"
else
    parallel-ssh -i -t 0 -h "$HOSTNAME" "/bin/bash ./grafana_setup.sh"
fi