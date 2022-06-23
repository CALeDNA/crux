#! /bin/bash

### this script is run as follows
# sh ~CRUX/crux_db/crux.sh  -n <Metabarcode locus primer set name>  -f <Metabarcode locus forward primer sequence>  -r <Metabarcode locus reverse primer sequence>  -s <Shortest amplicon expected>  -m <Longest amplicon expected>  -o <path to output directory>  -d <path to crux_db>  -x <If retaining intermediate files no argument needed>  -u <If running on an HPC this is your username: e.g. eecurd>  -l <If running locally no argument needed>  -k <Chunk size for breaking up blast seeds (default
# 500)> -e	<Maximum number of mismatch between primers and EMBL database sequences> -g <Maximum number of allowed errors for filtering and trimming the BLAST seed sequences with cutadapt> -t <The number of threads to launch for the first round of BLAST>  -v <The minimum accepted value for BLAST hits in the first round of BLAST >  -i <The minimum percent ID for BLAST hits in the first round of BLAST>  -c <Minimum percent of length of a query that a BLAST hit must cover >  -a <Maximum number of
# BLAST hits to return for each query>  -j <The number of threads to launch for the first round of BLAST>  -w <The minimum accepted value for BLAST hits in the first round of BLAST>  -p  <The minimum percent ID for BLAST hits in the first round of BLAST >  -f <Minimum percent of length of a query that a BLAST hit must cover>  -b <Job Submit header>  -h <Shows program usage then quits>

NAME=""
FP=""
RP=""
ODIR=""
DB=""
SHRT=""
LNG=""
CLEAN="TRUE"
UN=""
LOCALMODE="FALSE"
CHUNK=""
ERROR=""
CDERROR=""
THREAD1=""
EVAL1=""
ID1=""
COV1=""
RETURN=""
GO=""
GE=""
THREAD2=""
EVAL2=""
ID2=""
COV2=""
HEADER=""
HELP=""
ECOPCRDIR=""

while getopts "n:f:r:s:m:o:d:q?:u:l?:k:e:g:t:v:i:c:a:z:y:j:w:p:x:b:h?:1:" opt; do
    case $opt in
        n) NAME="$OPTARG"
        ;;
        f) FP="$OPTARG"
        ;;
        r) RP="$OPTARG"
        ;;
        s) SHRT="$OPTARG"
        ;;
	      m) LNG="$OPTARG"
        ;;
        o) ODIR="$OPTARG"
        ;;
        d) DB="$OPTARG"
        ;;
        q) CLEAN="FLASE"
        ;;
        u) UN="$OPTARG"
        ;;
        l) LOCALMODE="TRUE"
        ;;
        k) CHUNK="$OPTARG"
        ;;
        e) ERROR="$OPTARG"
        ;;
        g) CDERROR="$OPTARG"
        ;;
        t) THREAD1="$OPTARG"
        ;;
        v) EVAL1="$OPTARG"
        ;;
        i) ID1="$OPTARG"
        ;;
        c) COV1="$OPTARG"
        ;;
        a) RETURN="$OPTARG"
        ;;
        z) GO="$OPTARG"
        ;;
        y) GE="$OPTARG"
        ;;
        j) THREAD2="$OPTARG"
        ;;
        w) EVAL2="$OPTARG"
        ;;
        p) ID2="$OPTARG"
        ;;
        x) COV2="$OPTARG"
        ;;
        b) HEADER="$OPTARG"
        ;;
        h) HELP="TRUE"
        ;;
        1) ECOPCRDIR="$OPTARG"
        ;;
    esac
done

if [ "${HELP}" = "TRUE" ]
then
  printf "<<< CRUX: Sequence Creating Reference Libraries Using eXisting tools>>>\n\nThe purpose of these script is to generate metabarcode locus specific reference libraries. This script takes PCR primer sets, runs ecoPRC (in silico PCR) on EMBL (or other OBITools formatted) databases, then BLASTs the resulting sequences ncbi's nr database, and generates database files for unique NCBI sequences. The final databases are either filtered (sequences with ambiguous taxonomy removed) of unfiltered and consist of a fasta file, a taxonomy file, and a Bowtie2 Index library. \n	For successful implementation \n		1. Make sure you have all of the dependencies and correct paths in the crux_config.sh file\n		2. All parameters can be modified using the arguments below.  Alternatively, all parameters can be altered in the crux_vars.sh folder\n\nArguments:\n- Required:\n	-n	Metabarcode locus primer set name\n	-f	Metabarcode locus forward primer sequence  \n	-r	Metabarcode locus reverse primer sequence  \n	-s	Shortest amplicon expected (e.g. 100 bp shorter than the average amplicon length\n	-m	Longest amplicon expected (e.g. 100 bp longer than the average amplicon length\n	-o	path to output directory\n	-d	path to crux_db\n\n- Optional:\n	-q	If retaining intermediate files: -x (no argument needed; Default is to delete intermediate files) \n	-u	If running on an HPC (e.g. UCLA's Hoffman2 cluster), this is your username: e.g. eecurd\n	-l	If running locally: -l  (no argument needed)\n	-k	Chunk size for breaking up blast seeds (default 500)\n	-e	Maximum number of mismatch between primers and EMBL database sequences (default 3)\n	-g	Maximum number of allowed errors for filtering and trimming the BLAST seed sequences with cutadapt (default 0.3)\n	-t	The number of threads to launch for the first round of BLAST (default 10)\n	-v	The minimum accepted value for BLAST hits in the first round of BLAST (default 0.00001)\n	-i 	The minimum percent ID for BLAST hits in the first round of BLAST (default 50)\n	-c	Minimum percent of length of a query that a BLAST hit must cover (default 100)\n	-a	Maximum number of BLAST hits to return for each query (default 10000)\n	-z	BLAST gap opening penalty\n	-y	BLAST gap extension penalty\n	-j	The number of threads to launch for the first round of BLAST (default 10)\n	-w	The minimum accepted value for BLAST hits in the first round of BLAST (default 0.00001)\n	-p 	The minimum percent ID for BLAST hits in the first round of BLAST (default 70)\n	-x	Minimum percent of length of a query that a BLAST hit must cover (default 70)\n	-b	HPC mode header template\n\n- Other:\n	-h	Shows program usage then quits\n\n\n"
  exit
else
  echo ""
fi

case "$DB" in
*/)
    DB=${DB%/}
    ;;
*)
    echo ""
    ;;
esac

case "$OUT" in
*/)
    ODIR=${ODIR%/}
    ;;
*)
    echo ""
    ;;
esac

###########################################

# Emily Curd (eecurd@g.ucla.edu), Gaurav Kandlikar (gkandlikar@ucla.edu), and Jesse Gomer (jessegomer@gmail.com)
# Updated 07 September 2017

# this is a draft of a pipeline that takes any pair of primer sequences and generages a comprehensive reference database that could be amplified with those primers, using as much data from published sequences as posible.

# THE GOAL: is to capture not only the sequences that were submitted with primers included in the read (ecoPCR gets these), but also those that do not include primer regions but are some % of the length of the expected amplion (BLAST fills in these holes), and generate reference libraries and taxonomy files compatible with qiime or kraken taxonomy pipelines.

# Source the config and vars file so that we have programs and variables available to us

if [[ -z ${HEADER} ]];
then
  source $DB/scripts/HPC_mode_header.sh
else
  source ${HEADER}
fi

###Local or HPC mode check for username
if [[ "${LOCALMODE}" = "TRUE"  ]];
then
  echo "Running in local mode"
elif [[ "${LOCALMODE}" = "FALSE" && ! -z ${UN} ]];
then
  echo "Running in HPC mode"
elif [[ "${LOCALMODE}" = "FALSE" &&  -z ${UN} ]];
then
  echo "Running in HPC mode"
  echo "No username given..."
  echo ""
  exit
fi

#Check that user has all of the default flags set
if [[ ! -z ${ODIR} && -e ${DB} && ! -z ${FP} && ! -z ${RP} && ! -z ${SHRT} && ! -z ${LNG} && ! -z ${NAME} ]];
then
  echo "Required Arguments Given"
  echo ""
else
  echo "Required Arguments Missing:"
  echo "check that you included arguments or correct paths for -n -f -r -o -d -s and -m"
  echo ""
  exit
fi

source $DB/scripts/crux_vars.sh
source $DB/scripts/crux_config.sh

${MODULE_SOURCE}
${QIIME}
${BOWTIE2}
${ATS} #load ATS, Hoffman2 specific module for managing submitted jobs.


echo " "
mkdir -p ${ODIR}/Run_info/blast_jobs
mkdir -p ${ODIR}/Run_info/blast_logs
mkdir -p ${ODIR}/Run_info/cut_adapt_out


##########################
# Part 1.1: ecoPCR
##########################

echo " "
echo " "
echo "Part 1.1:"
echo "Run ecoPCR with ${NAME} primers F- ${FP} R- ${RP} and these parameters:"
echo "     missmatch = ${ERROR:=$ECOPCR_e}"
echo "     expected amplicon length between ${SHRT} and ${LNG}"
echo ""
###
mkdir -p ${ODIR}/${NAME}_ecoPCR
mkdir -p ${ODIR}/${NAME}_ecoPCR/raw_out/

if [ "${ECOPCRDIR}" = "" ]
then
  #run ecoPCR on each folder in the obitools database folder
  for db in ${OBI_DB}/OB_dat_*/
  do
  db1=${db%/}
  j=${db1#${OBI_DB}/}
  echo "..."${j}" ecoPCR is running"
  echo ${ecoPCR} -d ${db}${j} -e ${ERROR:=$ECOPCR_e} -l ${SHRT} -L ${LNG} ${FP} ${RP} -D 1 > ${ODIR}/${NAME}_ecoPCR/raw_out/${NAME}_${j}_ecoPCR_out
  ${ecoPCR} -d ${db}${j} -e ${ERROR:=$ECOPCR_e} -l ${SHRT} -L ${LNG} ${FP} ${RP} -D 1 > ${ODIR}/${NAME}_ecoPCR/raw_out/${NAME}_${j}_ecoPCR_out
  echo "..."${j}" ecoPCR is finished"
  echo ""
  date
  done
else
  echo "Skipping ecoPCR Part 1.1... copying ${ECOPCRDIR} to ${ODIR}/${NAME}_ecoPCR"
  cp -r ${ECOPCRDIR} ${ODIR}/${NAME}_ecoPCR
fi

###

##########################
# Part 1.2: ecoPCR
##########################

echo " "
echo " "
echo "Part 1.2:"
echo "Clean ${NAME} ecoPCR output for blasting"
mkdir -p ${ODIR}/cutadapt_files
mkdir -p ${ODIR}/${NAME}_ecoPCR/
mkdir -p ${ODIR}/${NAME}_ecoPCR/clean_up
mkdir -p ${ODIR}/${NAME}_ecoPCR/cleaned
# make primer files for cutadapt step
printf ">${NAME}_F\n${FP}\n>${NAME}_R\n${RP}" > "${ODIR}/cutadapt_files/${NAME}.fasta"
python ${DB}/scripts/crux_format_primers_cutadapt.py ${ODIR}/cutadapt_files/${NAME}.fasta ${ODIR}/cutadapt_files/g_${NAME}.fasta ${ODIR}/cutadapt_files/a_${NAME}.fasta
#run ecoPCR through cutadapt to verify that the primer seqeunce exists, and to trim it off
for str in ${ODIR}/${NAME}_ecoPCR/raw_out/*_ecoPCR_out
do
str1=${str%_ecoPCR_out}
j=${str1#${ODIR}/${NAME}_ecoPCR/raw_out/}
#reformat ecoPCR out and remove duplicate reads by taxid
tail -n +14 ${str} |cut -d "|" -f 3,21|sed "s/ | /,/g"|awk -F"," '!_[$1]++' | sed "s/\s//g" |awk 'BEGIN { FS=","; } {print ">"$1"\n"$2}' > ${ODIR}/${NAME}_ecoPCR/clean_up/${j}_ecoPCR_blast_input.fasta
#run cut adapt
${CUTADAPT} -e ${CDERROR:=$CUTADAPT_ERROR} -a file:${ODIR}/cutadapt_files/a_${NAME}.fasta  --untrimmed-output ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_untrimmed_1.fasta -o ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_ecoPCR_blast_input_a_clean.fasta ${ODIR}/${NAME}_ecoPCR/clean_up/${j}_ecoPCR_blast_input.fasta >> ${ODIR}/Run_info/cut_adapt_out/${j}_cutadapt-report.txt
${CUTADAPT} -e ${CDERROR:=$CUTADAPT_ERROR} -g file:${ODIR}/cutadapt_files/g_${NAME}.fasta  --untrimmed-output ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_untrimmed_2.fasta -o ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_ecoPCR_blast_input_a_and_g_clean.fasta ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_ecoPCR_blast_input_a_clean.fasta >> ${ODIR}/Run_info/cut_adapt_out/${j}_cutadapt-report.txt
echo "..."${j}" is clean"
date
done
###


###

##########################
# Part 2.1: Cleaning up blast results
##########################

################################ once all array jobs are finished run this script
echo " "
echo " "
echo "Part 2.1: Cleaning up blast results"
echo "For each set of BLAST 1 and 2 results"
echo "     Merge and De-replicate by NCBI accession version numbers, and convert to fasta format."
echo "     Then use entrez-qiime to generate a corresponding taxonomy file, and clean the blast output and taxonomy file to eliminate poorly annotated sequences."
mkdir -p ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/
mkdir -p ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy


# create reference fasta from blast
blastdbcmd -entry all -db ${BLAST_DB} -out ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy/${NAME}_.fasta


### add taxonomy using entrez_qiime.py
echo "...Running ${j} entrez-qiime and cleaning up fasta and taxonomy files"
echo python ${ENTREZ_QIIME} -i ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy/${NAME}_.fasta -o ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy -n ${TAXO} -a ${A2T} -r superkingdom,phylum,class,order,family,genus,species

python ${ENTREZ_QIIME} -i ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy/${NAME}_.fasta -o ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy -n ${TAXO} -a ${A2T} -r superkingdom,phylum,class,order,family,genus,species
# clean up reads based on low resolution taxonomy and store filtered reads in filtered file
python ${DB}/scripts/clean_blast.py ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy/${NAME}_.fasta ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/${NAME}_.fasta ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy.txt ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy.txt
python ${DB}/scripts/tax_fix.py ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy.txt ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy.txt.tmp
grep '[^[:blank:]]'  ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy.txt.tmp > ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy.txt
rm ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/${NAME}_taxonomy.txt.tmp
echo "... ${j} final fasta and taxonomy database complete"


##########################
# Part 2.2: Turn the reference libraries into Bowtie2 searchable libraries
##########################

echo " "
echo " "
echo "Part 2.2:"
echo "The bowtie2 database files for ${NAME} can be found in the ${NAME}_bowtie2_databases within the ${NAME}_db_unfiltered and ${NAME}_db_filtered folder's in ${ODIR}:"
#make bowtie2 databases for filtered and unfiltered database
mkdir -p ${ODIR}/${NAME}_db_unfiltered/${NAME}_bowtie2_database
bowtie2-build -f ${ODIR}/${NAME}_db_unfiltered/${NAME}_fasta_and_taxonomy/${NAME}_.fasta ${ODIR}/${NAME}_db_unfiltered/${NAME}_bowtie2_database/${NAME}_bowtie2_index
date
echo " "
echo " "
mkdir -p ${ODIR}/${NAME}_db_filtered/${NAME}_bowtie2_database/
bowtie2-build -f ${ODIR}/${NAME}_db_filtered/${NAME}_fasta_and_taxonomy/${NAME}_.fasta ${ODIR}/${NAME}_db_filtered/${NAME}_bowtie2_database/${NAME}_bowtie2_index
date
echo " "
echo " "



##########################
# Part 2.3: Delete the intermediate steps
##########################

echo " "
echo " "
echo "Part 2.3:"
echo "Deleting the intermediate files: ${CLEAN}"
#if [[ ${CLEAN} = "FALSE" ]];
# then
#    echo "nothing to delete"
# else
#    echo "Deleting"
#    echo "...${NAME} ecoPCR directory"
#    rm -r ${ODIR}/${NAME}_ecoPCR
#    echo "...${NAME} BLAST directory"
##    echo "...${NAME} first cluster step directory"
#fi
date
echo " "
echo " "
