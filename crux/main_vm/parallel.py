from pssh.clients import ParallelSSHClient
import argparse
import datetime

parser = argparse.ArgumentParser(description='')
parser.add_argument('--hosts', type=int)
parser.add_argument('--user', type=int)
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

# cmd='$(hostname)'
# output = client.run_command(cmd)
# for host_out in output:
#     for line in host_out.stdout:
#         print(line)
#     for line in host_out.stderr:
#         print(line)

cmd = './run.sh -i {date}'
output = client.run_command(cmd)
for host_out in output:
    for line in host_out.stdout:
        print(line)
    for line in host_out.stderr:
        print(line)