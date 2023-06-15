#! /bin/bash

QC=""
while getopts "h:c:p:u:s:q" opt; do
    case $opt in
        h) HOSTNAME="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
        p) PRIMERS="$OPTARG"
        ;;
        u) USER="$OPTARG"
        ;;
        s) START="$OPTARG"
        ;;
        q) QC="TRUE"
        ;;
    esac
done

sed -n "$(($START+1))"',$p' $HOSTNAME >> tmphost

parallel-ssh -i -t 0 -h tmphost "git clone -b crux-hector https://github.com/CALeDNA/crux.git"

parallel-scp -h tmphost $CONFIG /home/$USER/crux/crux/vars/

parallel-scp -h tmphost $PRIMERS /home/$USER/crux/crux/vars/

if [ "${QC}" = "TRUE" ]
then
    parallel-ssh -i -t 0 -h tmphost "cd crux/tronko/assign; docker build -q -t qc ."
else
    parallel-ssh -i -t 0 -h tmphost "cd crux; docker build -q -t crux ."
fi

rm tmphost