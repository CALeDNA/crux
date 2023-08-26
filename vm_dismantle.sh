#! /bin/bash
set -x

DASHBOARD=/var/lib/grafana/dashboards/overview.json
OS_USERNAME=""
APIKEY=""
JSCRED=""
HOSTNAME=""
NAME=""
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

mv $JSCRED $HOSTNAME $BASEDIR/crux/main
cd $BASEDIR/crux/main

# remove VM from ben server
/etc/ben/ben scale -n 0 $NAME --retire -s $BENSERVER # just in case
/etc/ben/ben kill $NAME -s $BENSERVER

# remove host from known_hosts
ssh-keygen -R $NAME

# delete VM
./dismantle_instance.sh -j $JSCRED -h $HOSTNAME -m $NAME -c $CONFIG -d $DATASOURCE


mv $JSCRED $HOSTNAME $BASEDIR
cd $BASEDIR/grafana/main
# update grafana dashboard
sudo python3 dashboard-mod.py --dashboard $DASHBOARD --datasource $DATASOURCE

# update ben panels in grafana
sudo python3 ben-dashboard-mod.py --dashboard $DASHBOARD

sudo systemctl restart grafana-server.service