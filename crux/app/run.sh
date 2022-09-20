#! /bin/bash

while getopts "i:" opt; do
    case $opt in
        i) RUNID="$OPTARG"
        ;;
    esac
done

# step 1: download github repo

# step 1:
docker run run_scheduler.sh -c crux.yaml
# crux.yaml: # of machines, etc
# run_scheduler: split urls, create VMs

# step 2:
docker run run_ecopcr.sh -c crux.yaml -p primers

# step 3:
# dl and combine all ecopcr fasta files by primer
gocmd -c ${CYVERSE} get /iplant/home/shared/eDNA_Explorer/ecopcr/${RUNID}/ ecopcr/

for d in /app/bwa/ecopcr/${RUNID}/*/
do
    cat ${d}*.fasta > "${d%/}".fasta
done

# step 4:
docker run run_bwa.sh

# step 5:
docker run tronko.sh
