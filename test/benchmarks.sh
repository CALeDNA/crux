#! /bin/bash

# run bowtie2
echo "running bowtie2"
# run bowtie on bowtie db and ecopcr output. Outputs a bam file
time bowtie2 -f -x bowtie/nt -U ecopcr_out.fasta | samtools view -bS - > bowtie_results.bam

# sort bam file
time samtools sort bowtie_results.bam -o bowtie_results.sorted.bam

# convert bam to fasta
time samtools view bowtie_results.sorted.bam | awk 'BEGIN { FS="\t"; } {print ">"$3"\n"$10}' >> bowtie_results.fasta

# # converts bam file into fasta
# time samtools fasta bowtie_results.bam > bowtie_results.fasta  # <- gets columns 1 and 3 but want 3 and 10

# get taxonomy
time python crux_db/scripts/entrez_qiime.py -i bowtie_results.fasta -o bowtie_results_taxonomy -n TAXO/ -a nucl_gb.accession2taxid -r superkingdom,phylum,class,order,family,genus,species

echo "finished bowtie2"



echo "running blast"
# run blast
time blastn -query ecopcr_out.fasta -out blast_results.txt -db blast/nt -outfmt "6 saccver staxid sseq"

# convert blast output to fasta
time cat blast_results.txt | sed "s/-//g" | awk 'BEGIN { FS="\t"; } {print ">"$1"\n"$3}' >> blast_results.fasta

# get taxonomy
time python crux_db/scripts/entrez_qiime.py -i blast_results.fasta -o blast_results_taxonomy -n TAXO/ -a nucl_gb.accession2taxid -r superkingdom,phylum,class,order,family,genus,species

echo "finished blast"



echo "running kraken2"
# run kraken
# returns with taxonomy
time kraken2 --use-names --db kraken/nt/ ecopcr_out.fasta --output kraken_results.txt

echo "finished kraken2"
