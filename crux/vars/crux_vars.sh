PRIMERS="primers" # primers file name
CYVERSE="config.yaml" # cyverse config file name
CYVERSE_BASE="/iplant/home/shared/eDNA_Explorer/crux"
THREADS=16
INDEX_THREADS=4 # each thread takes about 18GB of RAM
RUNID="2022-10-07"

# Obitools ecopcr variables
ERROR=3
MINLENGTH=100
MAXLENGTH=1000

# Jetstream2 variables and credentials
OS_USERNAME="ubuntu"
FLAVOR="m3.large"
IMAGE="Featured-Ubuntu20"
# create the ssh key
#ssh-keygen -b 2048 -t rsa -f ${APIKEY}
# upload to OpenStack
#openstack keypair create --public-key ${APIKEY}.pub ${APIKEY}
APIKEY="hbaez-api-key"
# include your Jetstream credentials openrc file
# https://github.com/jetstream-cloud/js2docs/blob/main/docs/ui/cli/openrc.md
JSCRED="app-cred-docker-cli-auth-openrc.sh"
NUMINSTANCES=10 # number of virtual machines
SECURITY="caledna-global-ssh"
VOLUME=300 # volume backed storage for virtual machines. 0 for default size

# accession ID file/folder names
LINKS="linksize"
URLS="urls"
NTOTAL=71 # number of nt chunks


# parallel.py docker commands
# DOCKER_BUILD="cd crux/crux; docker build -q -t crux ."
# ECOPCR_CMD="cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/ecopcr:/mnt -v $(pwd)/vars:/vars --name ecopcr crux /mnt/run_ecopcr.sh -c {config} -h ${{HOSTNAME}}"
# BWA_CMD="cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/bwa:/mnt -v $(pwd)/vars:/vars --name bwa crux /mnt/run_bwa.sh -c {config} -h ${{HOSTNAME}}"
# TAXFILTER_CMD="cd crux/crux; HOSTNAME=$(hostname | tr -dc '0-9'); docker run -t -v $(pwd)/app/taxfilter:/mnt -v $(pwd)/vars:/vars --name taxfilter crux /mnt/get-largest.sh -c {config} -h ${{HOSTNAME}}"
