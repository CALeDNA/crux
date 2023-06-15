#! /bin/bash

PROM_VERSION='2.42.0'
NODE_VERSION='1.5.0'
PUSHGATEWAY_VERSION='1.5.1'
ALERTMANAGER_VERSION='0.25.0'
LOKI_VERSION='2.8.0'
PROMTAIL_VERSION='2.8.0'
BEN_VERSION='2.12'

# prometheus setup
sudo useradd     --system     --no-create-home     --shell /bin/false prometheus

wget -q https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar -xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz

sudo mkdir -p /data /etc/prometheus

sudo mv prometheus-${PROM_VERSION}.linux-amd64/prometheus prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin
sudo chown -R prometheus:prometheus /etc/prometheus/ /data/
rm -r prometheus-${PROM_VERSION}.linux-amd64*

sudo cp prometheus.service /etc/systemd/system/prometheus.service
sudo cp prometheus.yml /etc/prometheus

sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus --no-pager


# node_exporter setup
sudo useradd     --system     --no-create-home     --shell /bin/false node_exporter

wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
tar -xvf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz

sudo mv node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -r node_exporter-${NODE_VERSION}.linux-amd64*

sudo cp node_exporter.service /etc/systemd/system/node_exporter.service

sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter --no-pager

sudo systemctl restart node_exporter


# grafana setup
sudo apt-get install -y apt-transport-https software-properties-common
wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add -
echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list
sudo apt-get update

sudo apt-get -y install grafana
sudo systemctl enable grafana-server
sudo systemctl start grafana-server

sudo systemctl status grafana-server --no-pager


# pushgateway setup
sudo useradd     --system     --no-create-home     --shell /bin/false pushgateway

wget https://github.com/prometheus/pushgateway/releases/download/v${PUSHGATEWAY_VERSION}/pushgateway-${PUSHGATEWAY_VERSION}.linux-amd64.tar.gz
tar -xvf pushgateway-${PUSHGATEWAY_VERSION}.linux-amd64.tar.gz
sudo mv pushgateway-${PUSHGATEWAY_VERSION}.linux-amd64/pushgateway /usr/local/bin/
rm -r pushgateway-${PUSHGATEWAY_VERSION}.linux-amd64*

sudo cp pushgateway.service /etc/systemd/system/pushgateway.service
sudo systemctl start pushgateway
sudo systemctl status pushgateway --no-pager


# alertmanager setup
sudo useradd     --system     --no-create-home     --shell /bin/false alertmanager

wget https://github.com/prometheus/alertmanager/releases/download/v${ALERTMANAGER_VERSION}/alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz
tar -xvf alertmanager-${ALERTMANAGER_VERSION}.linux-amd64.tar.gz

sudo mkdir -p /alertmanager-data /etc/alertmanager
sudo mv alertmanager-${ALERTMANAGER_VERSION}.linux-amd64/alertmanager /usr/local/bin/

rm -r alertmanager-${ALERTMANAGER_VERSION}.linux-amd64*

sudo cp alertmanager.yml /etc/alertmanager/alertmanager.yml
sudo cp alertmanager.service /etc/systemd/system/alertmanager.service
sudo systemctl enable alertmanager
sudo systemctl start alertmanager

sudo cp ben-error-rule.yml /etc/prometheus/ben-error-rule.yml


# loki and promtail setup
curl -O -L "https://github.com/grafana/loki/releases/download/v$LOKI_VERSION/loki-linux-amd64.zip"
unzip "loki-linux-amd64.zip"
chmod a+x loki-linux-amd64
rm loki-linux-amd64.zip

sudo mv loki-linux-amd64 /usr/local/bin/loki
loki --version

sudo mkdir -p /data/loki
sudo cp loki-local-config.yaml /etc/loki-local-config.yaml
sudo cp loki.service /etc/systemd/system/loki.service

curl -O -L "https://github.com/grafana/loki/releases/download/v$PROMTAIL_VERSION/promtail-linux-amd64.zip"
unzip promtail-linux-amd64.zip 
chmod a+x promtail-linux-amd64
rm promtail-linux-amd64.zip
sudo mv promtail-linux-amd64 /usr/local/bin/promtail
promtail --version

sudo cp promtail-local-config.yaml /etc/promtail-local-config.yaml
sudo cp promtail.service /etc/systemd/system/promtail.service

sudo systemctl daemon-reload
sudo systemctl start loki.service
sudo systemctl start promtail.service

systemctl status loki.service 
systemctl status promtail.service 


# ben setup
sudo useradd     --system     --no-create-home     --shell /bin/false ben
wget https://www.poirrier.ca/ben/ben-$BEN_VERSION.tar.gz
tar -xf ben-$BEN_VERSION.tar.gz
sudo apt install -y pandoc
cd ben && make && cd ..

sudo mkdir -p /etc/ben
sudo mkdir -p /etc/ben/output
sudo mv ben/ben /etc/ben/ben
sudo cp error_counter.sh /etc/ben/error_counter.sh
sudo cp node_util.py /etc/ben/node_util.py

sudo chown -R ben:ben /etc/ben

sudo cp ben-grafana.service ben-logs.service ben-logs.timer /etc/systemd/system
sudo systemctl start ben-logs.timer ben-logs.service

# start ben
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-ecopcr -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-blast -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-newick -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-tronko -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-assign -d

sudo systemctl start ben-grafana.service

sudo systemctl restart prometheus
sudo systemctl restart grafana
