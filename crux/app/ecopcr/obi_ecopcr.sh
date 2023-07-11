#!/bin/bash

set -x

LINK="" # file containing genbank links
PRIMER="" # primer
FORWARD=""
REVERSE=""
OUTPUT="" # folder to output fasta files
BATCHTAG="" # batch tag
ERROR="" # ecopcr error
MINLENGTH="" # ecopcr min length
MAXLENGTH="" # ecopcr max length

while getopts "l:p:f:r:m:n:o:b:e:c:" opt; do
    case $opt in
        l) LINK="$OPTARG"
        ;;
        p) PRIMER="$OPTARG"
        ;;
        f) FORWARD="$OPTARG"
        ;;
        r) REVERSE="$OPTARG"
        ;;
        m) MAXLENGTH="$OPTARG"
        ;;
        n) MINLENGTH="$OPTARG"
        ;;
        d) FOLDER="$OPTARG"
        ;;
        b) BATCHTAG="$(basename $OPTARG)"
        ;;
        e) ERROR="$OPTARG"
        ;;
        c) CONFIG="$OPTARG"
        ;;
    esac
done

retry() {
    local retries=$1
    local BATCHTAG=$2
    local PRIMER=$3
    local name=$4
    shift
    local cmd=("$@")
    
    local count=1
    local success=0
    
    while [[ $count -le $retries ]]; do
        "${cmd[@]}" && {
            success=1
            break
        }
        
        echo "Retry failed (${count}/${retries})"
        ((count++))
        #clean obitools databases
        obi clean_dms tax$BATCHTAG
        obi clean_dms gb$name
        # delete files
        rm -r output${name}_$PRIMER.obidms
        rm tmp${name}_$PRIMER.fasta
        rm OUTPUT/out_${BATCHTAG}_$PRIMER.fasta
        sleep 1
    done
    
    return $success
}


#import tax db
OUTPUT="$FOLDER/tax$BATCHTAG$BATCHTAG/OUTPUT"
mkdir -p $OUTPUT
cp taxdump.tar.gz $FOLDER/tax$BATCHTAG$BATCHTAG

cd $FOLDER/tax$BATCHTAG$BATCHTAG

TAXDB="tax$BATCHTAG/taxonomy/taxdump"
obi import --taxdump taxdump.tar.gz $TAXDB

wget -q --retry-connrefused --timeout=45 --tries=inf --continue -P GB/ $LINK
name="${LINK%.gbff.gz}"

# timeout -v 600s obi import --genbank-input GB/$LINK gb$name/$name
import_cmd=("timeout" "-v" "600s" "obi" "import" "--genbank-input" "GB/$LINK" "gb$name/$name")
retry $max_retries $BATCHTAG $PRIMER $name "${import_cmd[@]}"


if [ $MAXLENGTH -eq 0 ]
then
    # obi ecopcr -e $ERROR -l $MINLENGTH -F $FORWARD -R $REVERSE --taxonomy $TAXDB gb$name/$name output$name_$PRIMER/$name
    ecopcr_cmd=("obi" "ecopcr" "-e" "$ERROR" "-l" "$MINLENGTH" "-F" "$FORWARD" "-R" "$REVERSE" "--taxonomy" "$TAXDB" "gb$name/$name" "output${name}_$PRIMER/$name")
    retry $max_retries $BATCHTAG $PRIMER $name "${ecopcr_cmd[@]}"
else
    # obi ecopcr -e $ERROR -l $MINLENGTH -L $MAXLENGTH -F $FORWARD -R $REVERSE --taxonomy $TAXDB gb$name/$name output${name}_$PRIMER/$name
    ecopcr_cmd=("obi" "ecopcr" "-e" "$ERROR" "-l" "$MINLENGTH" "-L" "$MAXLENGTH" "-F" "$FORWARD" "-R" "$REVERSE" "--taxonomy" "$TAXDB" "gb$name/$name" "output${name}_$PRIMER/$name")
    retry $max_retries $BATCHTAG $PRIMER $name "${ecopcr_cmd[@]}"
fi

# obi export --fasta-output output${name}_$PRIMER/$name -o tmp${name}_$PRIMER.fasta
obi_cmd=("obi" "export" "--fasta-output" "output${name}_$PRIMER/$name" "-o" "tmp${name}_$PRIMER.fasta")
retry $max_retries $BATCHTAG $PRIMER $name "${obi_cmd[@]}"

cat tmp${name}_$PRIMER.fasta >> $OUTPUT/out_${BATCHTAG}_$PRIMER.fasta

#clean obitools databases
obi clean_dms tax${BATCHTAG}
obi clean_dms gb${name}
# delete files
rm -r output${name}_$PRIMER.obidms
rm tmp${name}_$PRIMER.fasta

# clean genbank input
rm -r gb$name.obidms
rm GB/$LINK

# cleanup
mv OUTPUT/* ../OUTPUT
cd ../../
# remove tax folder
rm -r $FOLDER/tax$BATCHTAG$BATCHTAG
