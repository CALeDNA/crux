# prepares databases for benchmarking kraken2 vs blastn vs bowtie2
# you can modify --threads 6 below to match how many cores you have

# compile kraken2 from src
git clone https://github.com/DerrickWood/kraken2
mkdir bin
cd kraken2
./install_kraken2.sh ../bin
echo "note you have to modify ./bin/add_to_library.sh in kraken2 to pass --lenient to scan_fasta_file.pl or this script will crash later"
cd ..

# download latest bowtie2 release
wget https://github.com/BenLangmead/bowtie2/releases/download/v2.4.5/bowtie2-2.4.5-linux-x86_64.zip
unzip bowtie2-2.4.5-linux-x86_64.zip -d bin
cp bin/bowtie2-2.4.5-linux-x86_64/bowtie2* bin/
rm bowtie2-2.4.5-linux-x86_64.zip
rm -rf bin/bowtie2-2.4.5-linux-x86_64

# download 2 blast NT chunks and convert to fasta
mkdir blast
cd blast
wget https://ftp.ncbi.nlm.nih.gov/blast/db/nt.00.tar.gz
wget https://ftp.ncbi.nlm.nih.gov/blast/db/nt.01.tar.gz
parallel --gnu tar -xzvf  ::: *gz
blastdbcmd -entry all -db nt -out ../nt-test.fasta
cd ..

# build bt2 db from 2 nt chunks
mkdir bowtie
cd bowtie
~/src/bowtie2/bowtie2-2.4.5-linux-x86_64/bowtie2-build --threads 6 -f ../nt-test.fasta nt
cd ..

# built kraken2 db from 2 nt chunks
mkdir kraken
cd kraken
# the following will take a while
./bin/kraken2-build --download-taxonomy --db nt
./bin/kraken2-build --threads 6 --no-masking --add-to-library ../nt-test.fasta --db nt
./bin/kraken2-build --build --threads 6 --db nt
cd ..
