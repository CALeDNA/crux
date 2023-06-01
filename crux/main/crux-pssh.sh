#! /bin/bash

QC=""
while getopts "h:c:p:u:q" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        p) PRIMERS="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        q) QC="TRUE"
        ;;
    esac
done

parallel-ssh -i -t 0 -h $HOSTNAME "git clone -b crux-hector https://github.com/CALeDNA/crux.git"

parallel-scp -h $HOSTNAME $CONFIG /home/$USER/crux/crux/vars/

parallel-scp -h $HOSTNAME $PRIMERS /home/$USER/crux/crux/vars/

if [ "${QC}" = "TRUE" ]
then
    parallel-ssh -i -t 0 -h $HOSTNAME "cd crux/tronko/assign; docker build -q -t qc ."
else
    parallel-ssh -i -t 0 -h $HOSTNAME "cd crux; docker build -q -t crux ."
fi
