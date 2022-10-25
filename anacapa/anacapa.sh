# EDIT THESE
DB="./anacapa_db" # path to anacapa_db
DATA="./anacapa-12s-test/12S_test_data" # change to input data folder
OUT="./anacapa-12s-test/out/12S_time_test" # change to output data folder

# OPTIONAL
FORWARD="$DATA/forward.txt"
REVERSE="$DATA/reverse.txt"

$DB/anacapa_QC_dada2.sh -i $DATA -o $OUT -d $DB -f $FORWARD -r $REVERSE -e $DB/metabarcode_loci_min_merge_length.txt -a truseq -t MiSeq -l -g