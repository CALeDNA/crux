#! /bin/bash
# main_grafana_setup.sh needs to run before this
BEN_VERSION='2.12'

# ben setup
wget https://www.poirrier.ca/ben/ben-$BEN_VERSION.tar.gz
tar -xf ben-$BEN_VERSION.tar.gz
sudo apt install -y pandoc
cd ben && make && cd ..

sudo mkdir -p /etc/ben
sudo mkdir -p /etc/ben/output
sudo mv ben/ben /etc/ben/ben

sudo cp node_util.py error_counter.sh /etc/ben/
sudo cp ben-jobs.service ben-logs.service ben-logs.timer /etc/systemd/system

# start ben
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-ecopcr -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-blast -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-newick -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-tronko -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-qc -d
sudo -H -u ben /etc/ben/ben server -s /tmp/ben-assign -d

sudo systemctl start ben-logs.service
sudo systemctl start ben-jobs.service

sudo systemctl status ben-logs --no-pager
sudo systemctl status ben-jobs --no-pager