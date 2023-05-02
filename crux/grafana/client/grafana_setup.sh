#! /bin/bash

PROM_VERSION='2.42.0'
NODE_VERSION='1.5.0'
# PUSHGATEWAY_VERSION='1.5.1'
# ALERTMANAGER_VERSION='0.25.0'

# prometheus setup
sudo useradd     --system     --no-create-home     --shell /bin/false prometheus

wget -q https://github.com/prometheus/prometheus/releases/download/v${PROM_VERSION}/prometheus-${PROM_VERSION}.linux-amd64.tar.gz
tar -xvf prometheus-${PROM_VERSION}.linux-amd64.tar.gz

sudo mkdir -p /data /etc/prometheus

sudo mv prometheus-${PROM_VERSION}.linux-amd64/prometheus prometheus-${PROM_VERSION}.linux-amd64/promtool /usr/local/bin
sudo chown -R prometheus:prometheus /etc/prometheus/ /data/
rm -r prometheus-${PROM_VERSION}.linux-amd64*

sudo mv ~/prometheus.service /etc/systemd/system/

sudo systemctl enable prometheus
sudo systemctl start prometheus
sudo systemctl status prometheus --no-pager


# node_exporter setup
sudo useradd     --system     --no-create-home     --shell /bin/false node_exporter

wget -q https://github.com/prometheus/node_exporter/releases/download/v${NODE_VERSION}/node_exporter-${NODE_VERSION}.linux-amd64.tar.gz
tar -xvf node_exporter-${NODE_VERSION}.linux-amd64.tar.gz

sudo mv node_exporter-${NODE_VERSION}.linux-amd64/node_exporter /usr/local/bin/
rm -r node_exporter-${NODE_VERSION}.linux-amd64*

sudo mv ~/node_exporter.service /etc/systemd/system/

sudo systemctl enable node_exporter
sudo systemctl start node_exporter
sudo systemctl status node_exporter --no-pager

sudo mv ~/prometheus.yml /etc/prometheus

sudo systemctl restart prometheus
sudo systemctl restart node_exporter