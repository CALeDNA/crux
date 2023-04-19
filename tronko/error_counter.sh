#! /bin/bash

#newerrors_log="newerrors.log"
#allerrors_log="allerrors.log"; touch $allerrors_log
log_dir=/home/ubuntu/ben/output
count=$(grep -E 'error|Error|Kill|fail|Fail' $log_dir/*log | wc -l)
echo "ben_errors_count $count" | curl --data-binary @- http://localhost:9091/metrics/job/backup

#grep -n -E 'error|Error|Kill|fail|Fail' $log_dir/* > $newerrors_log
#grep -vf $allerrors_log $newerrors_log >> tmp; mv tmp $newerrors_log # get lines in newerrors not in allerrors
#count=$(wc -l $newerrors_log | cut -d' ' -f1)
#echo $(tr --delete '\n' < $newerrors_log) > tmp; mv tmp $newerrors_log
#logs=$(cat $newerrors_log | sed "s/\"/'/g")
#grep -n -E 'error|Error|Kill|fail|Fail' $log_dir/* > $allerrors_log

#if [ -z "${logs}" ]
#then
#    echo "ben_new_error_logs{logs=\"no new logs\"} $count" | curl --data-binary @- http://localhost:9091/metrics/job/ben-error-logs
#else
#    echo "ben_new_error_logs{logs=\"$logs\"} $count" | curl --data-binary @- http://localhost:9091/metrics/job/ben-error-logs
#fi