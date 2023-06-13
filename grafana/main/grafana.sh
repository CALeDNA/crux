#! /bin/bash

set -x

DASHBOARD=/var/lib/grafana/dashboards/overview.json
datasources=datasources.yaml
DATASOURCE=/etc/grafana/provisioning/datasources/datasources.yaml
USER=ubuntu
START=0
NAME="chunk"
while getopts "h:p:u:s:n:" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        p) PKEY="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        s) START="$OPTARG"
        ;;
        n) NAME="$OPTARG"
        ;;
    esac
done

sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost
./crux/grafana/main/grafana-pssh.sh -h tmphost -u $USER

counter=0
if [ $START -gt 0 ]; then
    # use tmphost file
    hostnames=$(cat tmphost)
    for line in $hostnames
    do
        address=$(ssh -G $line | awk '/^hostname / { print $2 }')
        counter=$(printf '%02d' $counter)
        echo "  - name: $NAME$counter" >> $datasources
        echo "    type: prometheus" >> $datasources
        echo "    url: http://$address:9090" >> $datasources
        echo "    uid: $NAME$counter" >> $datasources
        echo "    readOnly: false" >> $datasources
        echo "    editable: true" >> $datasources
        echo "" >> $datasources
        counter=$(( 10#$counter + 1 ))
    done
    sudo cat $datasources >> $DATASOURCE
    rm $datasources
else
    hostnames=$(cat $HOSTNAME)
    echo "apiVersion: 1" >> $datasources
    echo "datasources:" >> $datasources
    for line in $hostnames
    do
        address=$(ssh -G $line | awk '/^hostname / { print $2 }')
        counter=$(printf '%02d' $counter)
        echo "  - name: $NAME$counter" >> $datasources
        echo "    type: prometheus" >> $datasources
        echo "    url: http://$address:9090" >> $datasources
        echo "    uid: $NAME$counter" >> $datasources
        echo "    readOnly: false" >> $datasources
        echo "    editable: true" >> $datasources
        echo "" >> $datasources
        counter=$(( 10#$counter + 1 ))
    done
    sudo mv $datasources $DATASOURCE
fi

rm tmphost $datasources

#update dashboard panels reflecting datasources.yaml changes
sudo python3 dashboard-mod.py --dashboard $DASHBOARD --datasource $DATASOURCE

sudo systemctl restart grafana-server
