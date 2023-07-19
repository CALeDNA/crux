#! /bin/bash
set -x

DASHBOARD=/var/lib/grafana/dashboards/overview.json
OS_USERNAME=""
APIKEY=""
JSCRED=""
HOSTNAME=""
NAME=""
while getopts "j:h:m:c:d:" opt; do
    case $opt in
        j) JSCRED="$OPTARG"
        ;;
        h) HOSTNAME="$OPTARG"
        ;;
        m) NAME="$OPTARG"
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
# 1) run dismantle_instance.sh
./dismantle_instance.sh -j $JSCRED -h $HOSTNAME -m $NAME -c $CONFIG -d $DATASOURCE


mv $JSCRED $HOSTNAME $BASEDIR
cd $BASEDIR/grafana/main
# 2) update grafana dashboard
sudo python3 dashboard-mod.py --dashboard $DASHBOARD --datasource $DATASOURCE
sudo systemctl restart grafana-server.service

# 3) update ben panels in grafana
sudo python3 ben-dashboard-mod.py --dashboard $DASHBOARD



