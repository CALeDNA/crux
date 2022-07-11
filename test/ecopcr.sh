#! /bin/bash


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
ERROR=""
CDERROR=""
HELP=""
ECOPCRDIR=""
SKIPBLAST="FALSE"

while getopts "n:f:r:s:m:o:d:l?:e:h?:p:" opt; do
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
        l) LOCALMODE="TRUE"
        ;;
        e) ERROR="$OPTARG"
        ;;
        h) HELP="TRUE"
        ;;
        p) ECOPCRDIR="$OPTARG"
        ;;
    esac
done

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

# Source the config and vars file so that we have programs and variables available to us
source $DB/scripts/HPC_mode_header.sh

source $DB/scripts/crux_vars.sh
source $DB/scripts/crux_config.sh

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
 echo ${CUTADAPT} -e ${CDERROR:=$CUTADAPT_ERROR} -a file:${ODIR}/cutadapt_files/a_${NAME}.fasta  --untrimmed-output ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_untrimmed_1.fasta -o ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_ecoPCR_blast_input_a_clean.fasta ${ODIR}/${NAME}_ecoPCR/clean_up/${j}_ecoPCR_blast_input.fasta >> ${ODIR}/Run_info/cut_adapt_out/${j}_cutadapt-report.txt
 ${CUTADAPT} -e ${CDERROR:=$CUTADAPT_ERROR} -a file:${ODIR}/cutadapt_files/a_${NAME}.fasta  --untrimmed-output ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_untrimmed_1.fasta -o ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_ecoPCR_blast_input_a_clean.fasta ${ODIR}/${NAME}_ecoPCR/clean_up/${j}_ecoPCR_blast_input.fasta >> ${ODIR}/Run_info/cut_adapt_out/${j}_cutadapt-report.txt
 ${CUTADAPT} -e ${CDERROR:=$CUTADAPT_ERROR} -g file:${ODIR}/cutadapt_files/g_${NAME}.fasta  --untrimmed-output ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_untrimmed_2.fasta -o ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_ecoPCR_blast_input_a_and_g_clean.fasta ${ODIR}/${NAME}_ecoPCR/cleaned/${j}_ecoPCR_blast_input_a_clean.fasta >> ${ODIR}/Run_info/cut_adapt_out/${j}_cutadapt-report.txt
 echo "..."${j}" is clean"
date
done
###
