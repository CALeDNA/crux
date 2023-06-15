#! /bin/bash

log_dir=/etc/ben/output
count=$(grep -E 'error|Error|Kill|fail|Fail' $log_dir/*log | wc -l)
echo "ben_errors_count $count" | curl --data-binary @- http://localhost:9091/metrics/job/backup