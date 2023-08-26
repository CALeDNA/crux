#! /bin/bash
# main_grafana_setup.sh needs to run before this
BEN_VERSION='2.14'

# ben setup
wget https://www.poirrier.ca/ben/ben-$BEN_VERSION.tar.gz
tar -xf ben-$BEN_VERSION.tar.gz
sudo apt install -y pandoc
cd ben && make && cd ..

sudo mkdir -p /etc/ben
sudo mkdir -p /etc/ben/output
sudo mkdir -p /etc/ben/jobs
sudo mkdir -p /etc/ben/queue
sudo mv ben/ben /etc/ben/ben

sudo cp node_util.py error_counter.sh /etc/ben/
sudo cp ben-jobs.service ben-jobs.timer ben-logs.service ben-logs.timer /etc/systemd/system

# start ben
/etc/ben/ben server --snapshot /etc/ben/queue/ecopcr.ini -s /tmp/ben-ecopcr -d
/etc/ben/ben server --snapshot /etc/ben/queue/blast.ini -s /tmp/ben-blast -d
/etc/ben/ben server --snapshot /etc/ben/queue/ac.ini -s /tmp/ben-ac -d
/etc/ben/ben server --snapshot /etc/ben/queue/newick.ini -s /tmp/ben-newick -d
/etc/ben/ben server --snapshot /etc/ben/queue/tronko.ini -s /tmp/ben-tronko -d
/etc/ben/ben server --snapshot /etc/ben/queue/qc.ini -s /tmp/ben-qc -d
/etc/ben/ben server --snapshot /etc/ben/queue/assign.ini -s /tmp/ben-assign -d

sudo systemctl enable ben-logs.service
sudo systemctl enable ben-jobs.service
sudo systemctl enable ben-logs.timer
sudo systemctl enable ben-jobs.timer
sudo systemctl start ben-logs.service
sudo systemctl start ben-jobs.service
sudo systemctl start ben-logs.timer
sudo systemctl start ben-jobs.timer

sudo systemctl status ben-logs --no-pager
sudo systemctl status ben-jobs --no-pager