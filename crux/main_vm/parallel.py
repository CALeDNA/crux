from pssh.clients import ParallelSSHClient
import argparse
import datetime
from gevent import joinall

parser = argparse.ArgumentParser(description='')
parser.add_argument('--hosts', type=str)
parser.add_argument('--user', type=str)
parser.add_argument('--pkey', type=str)
parser.add_argument('--config', type=str)
parser.add_argument('--primers', type=str)
parser.add_argument('--cyverse', type=str)
args = parser.parse_args()

hostnames = args.hosts
user = args.user
pkey = args.pkey
config = args.config
primers = args.primers
cyverse = args.cyverse

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

# # copy config, primer, etc. files to VMs
cmd = client.copy_file('vars', 'crux/crux/vars', recurse=True)
joinall(cmd, raise_error=True)
# cmd = client.copy_file(f'{cyverse}', f'{cyverse}')
# joinall(cmd, raise_error=True)

# cmd = client.copy_file(f'{config}', f'{config}')
# joinall(cmd, raise_error=True)

# cmd = client.copy_file(f'{primers}', f'{primers}')
# joinall(cmd, raise_error=True)


#create swap space
cmd = 'sudo fallocate -l 10G /swapfile; sudo mkswap /swapfile; sudo swapon /swapfile'
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)

# build docker
cmd = 'cd crux/crux; docker build -q -t crux .'
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)

# run ecopcr
cmd = f"cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/ecopcr:/mnt -v $(pwd)/vars:/vars --name ecopcr crux /mnt/run_ecopcr.sh -c {config} -h ${{HOSTNAME}}"
output = client.run_command(cmd)
for host_out in output:
   for line in host_out.stdout:
       print(line)
   for line in host_out.stderr:
       print(line)

# run bwa
cmd = f"cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/bwa:/mnt -v $(pwd)/vars:/vars --name bwa crux /mnt/run_bwa.sh -c {config} -h ${{HOSTNAME}}"
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)

# run taxfilter
cmd = f"cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/taxfilter:/mnt -v $(pwd)/vars:/vars --name taxfilter crux /mnt/get-largest.sh -c {config} -h ${{HOSTNAME}}"
output = client.run_command(cmd)
for host_out in output:
   for line in host_out.stdout:
       print(line)
   for line in host_out.stderr:
       print(line)
