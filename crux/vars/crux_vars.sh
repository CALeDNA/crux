PRIMERS="/home/ubuntu/crux/crux/vars/primers" # primers file name
CYVERSE="/vars/config.yaml" # cyverse config file name
CYVERSE_BASE="/iplant/home/shared/eDNA_Explorer/crux"
BWA_INDEX_URL="https://data.cyverse.org/dav-anon${CYVERSE_BASE}/bwa-index"
THREADS=16
BLAST_THREADS=16
RUNID="2023-04-07"

# Obitools ecopcr variables
ERROR=3
# MINLENGTH=30
# MAXLENGTH=1000

# BLAST variables
eVALUE="0.00001"
PERC_IDENTITY="70"
NUM_ALIGNMENTS="1000"
GAP_OPEN="1"
GAP_EXTEND="1"

# Jetstream2 variables and credentials
USER="ubuntu"
FLAVOR="m3.large"
IMAGE="Featured-Ubuntu22"
# create the ssh key
#ssh-keygen -b 2048 -t rsa -f ${SSHKEY}
# upload to OpenStack
#openstack keypair create --public-key ${SSHKEY}.pub ${SSHKEY}
SSHKEY="hbaez-private-key"
# include your Jetstream credentials openrc file
# https://github.com/jetstream-cloud/js2docs/blob/main/docs/ui/cli/openrc.md
JSCRED="app-cred-docker-cli-auth-openrc.sh"
NUMINSTANCES=10 # number of virtual machines
SECURITY="exosphere"
NETWORK=ef65cd35-08de-4d4c-a664-e9b1aed32793
VOLUME=1000 # volume backed storage for virtual machines. 0 for default size

# accession ID file/folder names
#LINKS="wgsgbsize"
URLS="urls"
ECOPCRLINKS=142 # number of wgs/gb links files
NTOTAL=108 # number of nt chunks
NTFILE="nt-ftp"

IPADDRESS="0.0.0.0"
HOSTNAME="hostnames"
SSHCONFIG="/home/$USER/.ssh/config"

#GRAFANA
DATASOURCE="/etc/grafana/provisioning/datasources/datasources.yaml"

#AUTOSCALING
MAX_TOTAL=22
MAX_ECOPCR=5
MAX_BLAST=5
MAX_AC=5
MAX_NEWICK=5
MAX_TRONKO=5
MAX_QC=2
MAX_ASSIGN=5



# parallel.py docker commands
# DOCKER_BUILD="cd crux/crux; docker build -q -t crux ."
# ECOPCR_CMD="cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/ecopcr:/mnt -v $(pwd)/vars:/vars --name ecopcr crux /mnt/run_ecopcr.sh -c {config} -h ${{HOSTNAME}}"
# BWA_CMD="cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/bwa:/mnt -v $(pwd)/vars:/vars --name bwa crux /mnt/run_bwa.sh -c {config} -h ${{HOSTNAME}}"
# TAXFILTER_CMD="cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/taxfilter:/mnt -v $(pwd)/vars:/vars --name taxfilter crux /mnt/get-largest.sh -c {config} -h ${{HOSTNAME}}"