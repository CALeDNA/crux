#! /bin/bash

set -x

datasources=datasources.yaml
datasources_path=/etc/grafana/provisioning/datasources/datasources.yaml
USER=ubuntu
while getopts "h:p:u:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        p) PKEY="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
    esac
done

# create datasource.yml for hosts
echo "apiVersion: 1" >> $datasources
echo "datasources:" >> $datasources
echo "  - name: client" >> $datasources
echo "    type: prometheus" >> $datasources
echo "    url: http://localhost:9090" >> $datasources
echo "    isDefault: true" >> $datasources


python3 grafana.py --hosts $HOSTNAME --user $USER --pkey $PKEY
rm $datasources

hostnames=$(cat $HOSTNAME)
counter=0
echo "apiVersion: 1" >> $datasources
echo "datasources:" >> $datasources
for line in $hostnames
do
    counter=$(printf '%02d' $counter)
    echo "  - name: chunk$counter" >> $datasources
    echo "    type: prometheus" >> $datasources
    echo "    url: http://$line:9090" >> $datasources
    echo "    uid: chunk$counter" >> $datasources
    echo "" >> $datasources
    counter=$(( 10#$counter + 1 ))
done

sudo mv $datasources $datasources_path
sudo mkdir /var/lib/grafana/dashboards

sudo systemctl restart grafana-server
