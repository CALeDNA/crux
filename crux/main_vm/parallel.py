from pssh.clients import ParallelSSHClient
import argparse
from gevent import joinall

parser = argparse.ArgumentParser(description='')
parser.add_argument('--hosts', type=str)
parser.add_argument('--user', type=str)
parser.add_argument('--pkey', type=str)
parser.add_argument('--config', type=str)
parser.add_argument('--primers', type=str)
parser.add_argument('--cyverse', type=str)
parser.add_argument('--aws_key', type=str)
parser.add_argument('--aws_secret', type=str)
parser.add_argument('--aws_region', type=str)
args = parser.parse_args()

hostnames = args.hosts
user = args.user
pkey = args.pkey
config = args.config
primers = args.primers
cyverse = args.cyverse
aws_key=args.aws_key
aws_secret=args.aws_secret
aws_region=args.aws_region

hosts = []
with open(hostnames, 'r') as file:
    hostlines = file.readlines()

for line in hostlines:
    hosts.append(line.rstrip('\n'))
print(hosts)

client = ParallelSSHClient(hosts, user=user, pkey=pkey)

def runcmd(cmd):
    output = client.run_command(cmd)
    for host_out in output:
        for line in host_out.stdout:
            print(line)
        for line in host_out.stderr:
            print(line)

# clone gh repo
cmd = 'git clone -b crux-hector https://github.com/CALeDNA/crux.git'
runcmd(cmd)

# copy config, primer, etc. files to VMs
cmd = client.copy_file('vars', 'crux/crux/vars', recurse=True)
joinall(cmd, raise_error=True)

# copy aws
#cmd = client.copy_file('/home/exouser/.aws', '.aws', recurse=True)
#joinall(cmd, raise_error=False)

# #create swap space
# cmd = 'sudo fallocate -l 20G /swapfile; sudo mkswap /swapfile; sudo swapon /swapfile'
# runcmd(cmd)

# build docker
cmd = 'cd crux; docker build -q -t crux .'
runcmd(cmd)

# run ecopcr
cmd = f"cd crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/crux/app/ecopcr:/mnt -v $(pwd)/crux/vars:/vars -e AWS_ACCESS_KEY_ID={aws_key} -e AWS_SECRET_ACCESS_KEY={aws_secret} -e AWS_DEFAULT_REGION={aws_region} --name ecopcr crux /mnt/run_ecopcr.sh -c {config} -h ${{HOSTNAME}}"
runcmd(cmd)

# run blast
cmd = f"cd crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/crux/app/blast:/mnt -v $(pwd)/crux/vars:/vars -e AWS_ACCESS_KEY_ID={aws_key} -e AWS_SECRET_ACCESS_KEY={aws_secret} -e AWS_DEFAULT_REGION={aws_region} --name blast crux /mnt/run_blast.sh -c {config} -h ${{HOSTNAME}}"
runcmd(cmd)

# run bwa & taxfilter
cmd = f"cd crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/crux/app/taxfilter:/mnt -v $(pwd)/crux/vars:/vars -e AWS_ACCESS_KEY_ID={aws_key} -e AWS_SECRET_ACCESS_KEY={aws_secret} -e AWS_DEFAULT_REGION={aws_region} --name taxfilter crux /mnt/get-largest.sh -c {config} -h ${{HOSTNAME}}"
runcmd(cmd)
