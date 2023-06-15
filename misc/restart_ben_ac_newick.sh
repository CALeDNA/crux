#! /bin/bash
set -x

# restart ben after a crash / resize
output="/home/ubuntu/ben/output/"
cutoff_length=25000
folders=$(aws s3 ls s3://ednaexplorer/tronko/2022-12-27/ --endpoint-url https://js2.jetstream-cloud.org:8001/)

for folder in $folders
do
    if [ $folder == "PRE" ]
    then
        echo "skip PRE"
    else
        aws s3 sync s3://ednaexplorer/tronko/2022-12-27/$folder $folder --exclude "*" --include "*_taxonomy.txt" --no-progress --endpoint-url https://js2.jetstream-cloud.org:8001/
        added_job="FALSE"
        for file in $folder*
        do
            len=$(wc -l $file | cut -d ' ' -f1)
            if (( $len > $cutoff_length ))
            then
                added_job="TRUE"
                folder=$( echo $file | rev | cut -d"/" -f2 | rev )
                taxa=$( basename $file )
                job=$( echo $taxa | sed 's/_[^_]*$//g')
                fasta="${job}.fasta"
                job=$(printf '%02d' "$job") # add leading zero
                job="${folder}${job}"
                ben add -c "./run_ac.sh -d ${folder} -t ${taxa} -f ${fasta} -k ${AWS_ACCESS_KEY_ID} -s ${AWS_SECRET_ACCESS_KEY} -r ${AWS_DEFAULT_REGION} -j ${job} -i ${RUNID}" $job -o $output

            fi
        done
        JOB=${folder%/}
        # if new output folder added a job, skip. otherwise start ac2newick
        if [ "$added_job" = "FALSE" ]
        then
            if [ $( echo $JOB | rev | cut -d"-" -f1 | rev | tr -d [0-9]) != "ac" ]
            then
                echo "parent folder is root ancestralclust folder"
            else
                primer=$( echo $JOB | sed 's/-[^-]*$//g' ) # FOLDER="Cytb_Fish-ac00"
                suffix=$( echo $JOB | rev | cut -d'-' -f1 | rev | tr -dc '0-9' )
                job="${primer}-newick${suffix}"
                # ben add -c "docker run -t -v $(pwd):/mnt --name ${job} -e AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID} -e AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY} -e AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION} crux /mnt/ac2newick.sh -d ${JOB} -j ${job} -i ${RUNID}" ${job} -f main -o output
                if [[ $(aws s3 ls s3://ednaexplorer/tronko/2022-12-27/$job/ | head) ]]
                then
                    echo "$job done"
                else
                    ben add -c "./ac2newick.sh -d ${JOB} -k ${AWS_ACCESS_KEY_ID} -s ${AWS_SECRET_ACCESS_KEY} -r ${AWS_DEFAULT_REGION} -j ${job} -i ${RUNID}" $job -o $output
                fi
            fi
        fi
        rm -r $folder
    fi
done