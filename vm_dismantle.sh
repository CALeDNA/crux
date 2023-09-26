#! /bin/bash

DASHBOARD=/var/lib/grafana/dashboards/overview.json
OS_USERNAME=""
JSCRED=""
HOSTNAME=""
NAME=""
USER="ubuntu"
while getopts "j:h:m:e:c:d:" opt; do
    case $opt in
        j) JSCRED="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        m) NAME="$OPTARG"
        ;;
        e) BENSERVER="$OPTARG"
        ;;
        c) CONFIG="$OPTARG" # SSH config file: /home/ubuntu/.ssh/config
        ;;
        d) DATASOURCE="$OPTARG"
        ;;
    esac
done

BASEDIR=$(pwd)

mv $HOSTNAME $BASEDIR/crux/main
cd $BASEDIR/crux/main

# remove VM from ben server
/etc/ben/ben scale -n 0 $NAME -s $BENSERVER # just in case
/etc/ben/ben kill $NAME -s $BENSERVER

# remove host from known_hosts
address=$(ssh -G "$NAME" | awk '/^hostname / {print $2}')
ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R "$address"

# delete VM
./dismantle_instance.sh -j $JSCRED -h $HOSTNAME -m $NAME -c $CONFIG -d $DATASOURCE


mv $HOSTNAME $BASEDIR
cd $BASEDIR/grafana/main
# update grafana dashboard
sudo python3 dashboard-mod.py --dashboard $DASHBOARD --datasource $DATASOURCE

# update ben panels in grafana
sudo python3 ben-dashboard-mod.py --dashboard $DASHBOARD

sudo systemctl restart grafana-server.service