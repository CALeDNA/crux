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

# 1) run dismantle_instance.sh
./crux/main/dismantle_instance.sh -j $JSCRED -h $HOSTNAME -m $NAME -c $CONFIG -d $DATASOURCE

# 2) update grafana dashboard
sudo ./grafana/main/dashboard-mod.py --dashboard $DASHBOARD --datasource $DATASOURCE
sudo systemctl restart grafana-server.service

# 3) update ben panels in grafana
sudo ./grafana/main/ben-dashboard-mod.py --dashboard $DASHBOARD



