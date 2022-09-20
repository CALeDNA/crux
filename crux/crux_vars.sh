PRIMERS="primers" # primers file name
CYVERSE="config.yaml" # cyverse config file name
THREADS=16
RUNID="2022-09-16"

# Obitools ecopcr variables
ERROR=3
MINLENGTH=100
MAXLENGTH=1000

# Jetstream2 variables and credentials
OS_USERNAME="hbaez"
FLAVOR="m3.large"
# create the ssh key
#ssh-keygen -b 2048 -t rsa -f ${APIKEY}
# upload to OpenStack
#openstack keypair create --public-key ${APIKEY}.pub ${APIKEY}
APIKEY="hbaez-api-key"
# include your Jetstream credentials openrc file
# https://github.com/jetstream-cloud/js2docs/blob/main/docs/ui/cli/openrc.md
JSCRED="app-cred-docker-cli-auth-openrc.sh"
NUMINSTANCES=2 # number of virtual machines
SECURITY="caledna-global-ssh"
VOLUME=0 # volume backed storage for virtual machines. 0 for default size

# accession ID file/folder names
LINKS="linksize"
URLS="urls"