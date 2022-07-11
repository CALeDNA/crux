## Setup
- Run ecopcr to obtain ecopcr_out.fasta
  -  ./ecopcr.sh -n ITS2 -f ATGCGATACTTGGTGTGAAT -r GACGCTTCTCCAGACTACAAT -s 30 -m 200 -e 3 -o ITS2 -d ./ -l -p ITS2_ecoPCR/raw_out/
- Combine all ecopcr cleaned output into one fasta file
  - cat ITS2/ITS2_ecoPCR/cleaned/*a_and_g_clean.fasta >> ecopcr_out.fasta
- blast, bowtie and kraken databases are available on cyverse: de.cyverse.org/data/ds/iplant/home/shared/eDNA_Explorer/data
- to mount, install irodsfs: https://github.com/cyverse/irodsfs/blob/main/README.md
- Run benchmarks.sh (might have to modify the paths)
