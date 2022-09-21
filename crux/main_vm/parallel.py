from pssh.clients import ParallelSSHClient
import argparse
import datetime
from gevent import joinall

parser = argparse.ArgumentParser(description='')
parser.add_argument('--hosts', type=str)
parser.add_argument('--user', type=str)
parser.add_argument('--pkey', type=str)
args = parser.parse_args()

hostnames = args.hosts
user = args.user
pkey = args.pkey

date = datetime.datetime.now()
date = str(date).split(" ")[0]

hosts = []
with open(hostnames, 'r') as file:
    hostlines = file.readlines()

for line in hostlines:
    hosts.append(line.rstrip('\n'))
print(hosts)

client = ParallelSSHClient(hosts, user=user, pkey=pkey)

# clone gh repo
cmd = 'git clone -b crux-hector https://github.com/CALeDNA/crux.git'
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)

# copy config, primer, etc. files to VMs
cmd = client.copy_file('config.yaml', 'crux/crux/app/bwa/config.yaml')
joinall(cmd, raise_error=True)

cmd = client.copy_file('config.yaml', 'crux/crux/app/ecopcr/config.yaml')
joinall(cmd, raise_error=True)

cmd = client.copy_file('config.yaml', 'crux/crux/app/taxfilter/config.yaml')
joinall(cmd, raise_error=True)

cmd = client.copy_file('crux_vars.sh', 'crux/crux/app/bwa/crux_vars.sh')
joinall(cmd, raise_error=True)

cmd = client.copy_file('crux_vars.sh', 'crux/crux/app/ecopcr/crux_vars.sh')
joinall(cmd, raise_error=True)

cmd = client.copy_file('crux_vars.sh', 'crux/crux/app/taxfilter/crux_vars.sh')
joinall(cmd, raise_error=True)

cmd = client.copy_file('primers', 'crux/crux/app/ecopcr/primers')
joinall(cmd, raise_error=True)

cmd = client.copy_file('primers', 'crux/crux/app/taxfilter/primers')
joinall(cmd, raise_error=True)

# build docker
cmd = 'cd crux/crux; docker build -t crux .'
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)

# run ecopcr
cmd = "cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/ecopcr:/mnt --name ecopcr crux /mnt/run_ecopcr.sh -c crux_vars.sh -h ${HOSTNAME}"
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)

# run bwa
cmd = "cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/bwa:/mnt --name bwa crux /mnt/run_bwa.sh -c crux_vars.sh -h ${HOSTNAME}"
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)

# run taxfilter
cmd = "cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/taxfilter:/mnt --name taxfilter crux /mnt/get-largest.sh -c crux_vars.sh -h ${HOSTNAME}"
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)

# # run commands inside docker container
# cmd = 'cd crux/crux; ./run.sh -i {date}'
# output = client.run_command(cmd)
# for host_out in output:
#     for line in host_out.stdout:
#         print(line)
#     for line in host_out.stderr:
#         print(line)