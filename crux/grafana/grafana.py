from pssh.clients import ParallelSSHClient
import argparse
from gevent import joinall

parser = argparse.ArgumentParser(description='')
parser.add_argument('--hosts', type=str)
parser.add_argument('--user', type=str)
parser.add_argument('--pkey', type=str)
args = parser.parse_args()

hostnames = args.hosts
user = args.user
pkey = args.pkey

PROM_VERSION='2.42.0'
NODE_VERSION='1.5.0'
PUSHGATEWAY_VERSION='1.5.1'
ALERTMANAGER_VERSION='0.25.0'

hosts = []
with open(hostnames, 'r') as file:
    hostlines = file.readlines()

for line in hostlines:
    hosts.append(line.rstrip('\n'))
print(hosts)

client = ParallelSSHClient(hosts, user=user, pkey=pkey)

def runcmd(cmd, sudo=False):
    output = client.run_command(cmd, sudo=sudo)
    for host_out in output:
        for line in host_out.stdout:
            print(line)
        for line in host_out.stderr:
            print(line)

# prometheus setup
cmd = 'sudo useradd     --system     --no-create-home     --shell /bin/false prometheus'
runcmd(cmd)

cmd = f'wget -q https://github.com/prometheus/prometheus/releases/download/v{PROM_VERSION}/prometheus-{PROM_VERSION}.linux-amd64.tar.gz; tar -xvf prometheus-{PROM_VERSION}.linux-amd64.tar.gz'
runcmd(cmd)

cmd = 'sudo mkdir -p /data /etc/prometheus'
runcmd(cmd)

cmd = f'sudo mv prometheus-{PROM_VERSION}.linux-amd64/prometheus prometheus-{PROM_VERSION}.linux-amd64/promtool /usr/local/bin; sudo chown -R prometheus:prometheus /etc/prometheus/ /data/; rm -r prometheus-{PROM_VERSION}.linux-amd64*'
runcmd(cmd)

cmd = client.copy_file('prometheus.service', f'/home/{user}/prometheus.service')
joinall(cmd, raise_error=True)

cmd = f'sudo mv /home/{user}/prometheus.service /etc/systemd/system/'
runcmd(cmd)

cmd = 'sudo systemctl enable prometheus; sudo systemctl start prometheus'
runcmd(cmd)

# node_exporter setup
cmd = 'sudo useradd     --system     --no-create-home     --shell /bin/false node_exporter'
runcmd(cmd)

cmd = f'wget -q https://github.com/prometheus/node_exporter/releases/download/v{NODE_VERSION}/node_exporter-{NODE_VERSION}.linux-amd64.tar.gz; tar -xvf node_exporter-{NODE_VERSION}.linux-amd64.tar.gz'
runcmd(cmd)

cmd = f'sudo mv   node_exporter-{NODE_VERSION}.linux-amd64/node_exporter   /usr/local/bin/; rm -r node_exporter-{NODE_VERSION}.linux-amd64*'
runcmd(cmd)

cmd = client.copy_file('node_exporter.service', f'/home/{user}/node_exporter.service')
joinall(cmd, raise_error=True)

cmd = f'sudo mv /home/{user}/node_exporter.service /etc/systemd/system/'
runcmd(cmd)

cmd = 'sudo systemctl enable node_exporter; sudo systemctl start node_exporter'
runcmd(cmd)

# grafana setup
cmd = 'sudo apt-get install -y apt-transport-https software-properties-common'
runcmd(cmd)

cmd = 'wget -q -O - https://packages.grafana.com/gpg.key | sudo apt-key add - ; echo "deb https://packages.grafana.com/oss/deb stable main" | sudo tee -a /etc/apt/sources.list.d/grafana.list'
runcmd(cmd)

cmd = 'sudo apt-get update; sudo apt-get -y install grafana'
runcmd(cmd)

cmd = 'sudo systemctl enable grafana-server; sudo systemctl start grafana-server'
runcmd(cmd)

cmd = client.copy_file('datasources.yaml', f'/home/{user}/datasources.yaml')
joinall(cmd, raise_error=True)

cmd = f'sudo mv /home/{user}/datasources.yaml /etc/grafana/provisioning/datasources/'
runcmd(cmd)

cmd = 'sudo systemctl restart grafana-server'
runcmd(cmd)

# pushgateway setup
cmd = 'sudo useradd     --system     --no-create-home     --shell /bin/false pushgateway'
runcmd(cmd)

cmd = f'wget -q https://github.com/prometheus/pushgateway/releases/download/v{PUSHGATEWAY_VERSION}/pushgateway-{PUSHGATEWAY_VERSION}.linux-amd64.tar.gz; tar -xvf pushgateway-{PUSHGATEWAY_VERSION}.linux-amd64.tar.gz; sudo mv pushgateway-{PUSHGATEWAY_VERSION}.linux-amd64/pushgateway /usr/local/bin/; rm -r pushgateway-{PUSHGATEWAY_VERSION}.linux-amd64*'
runcmd(cmd)

cmd = client.copy_file('pushgateway.service', f'/home/{user}/pushgateway.service')
joinall(cmd, raise_error=True)

cmd = f'sudo mv /home/{user}/pushgateway.service /etc/systemd/system/'
runcmd(cmd)

cmd = 'sudo systemctl enable pushgateway; sudo systemctl start pushgateway'
runcmd(cmd)

# alermanager setup
cmd = 'sudo useradd     --system     --no-create-home     --shell /bin/false alertmanager'
runcmd(cmd)

cmd = f'wget -q https://github.com/prometheus/alertmanager/releases/download/v{ALERTMANAGER_VERSION}/alertmanager-{ALERTMANAGER_VERSION}.linux-amd64.tar.gz; tar -xvf alertmanager-{ALERTMANAGER_VERSION}.linux-amd64.tar.gz'
runcmd(cmd)

cmd = f'sudo mkdir -p /alertmanager-data /etc/alertmanager; sudo mv alertmanager-{ALERTMANAGER_VERSION}.linux-amd64/alertmanager /usr/local/bin/; sudo mv alertmanager-{ALERTMANAGER_VERSION}.linux-amd64/alertmanager.yml /etc/alertmanager/; rm -r alertmanager-{ALERTMANAGER_VERSION}.linux-amd64*'
runcmd(cmd)

cmd = client.copy_file('alertmanager.service', f'/home/{user}/alertmanager.service')
joinall(cmd, raise_error=True)

cmd = f'sudo mv /home/{user}/alertmanager.service /etc/systemd/system/'
runcmd(cmd)

cmd = 'sudo systemctl enable alertmanager; sudo systemctl start alertmanager'
runcmd(cmd)

# setup dead-mans-snitch rule
cmd = client.copy_file('dead-mans-snitch-rule.yml', f'/home/{user}/dead-mans-snitch-rule.yml')
joinall(cmd, raise_error=True)

cmd = f'sudo mv /home/{user}/dead-mans-snitch-rule.yml /etc/prometheus'
runcmd(cmd)

cmd = client.copy_file('prometheus.yml', f'/home/{user}/prometheus.yml')
joinall(cmd, raise_error=True)

cmd = f'sudo mv /home/{user}/prometheus.yml /etc/prometheus'
runcmd(cmd)