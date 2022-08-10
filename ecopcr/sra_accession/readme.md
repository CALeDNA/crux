# Collecting and Downloading SRA Accession IDs

- run sra_accession.py using the following command:
  - python3 sra_accession.py --input "prefixes" --output "links"

- to download the links:
  -  split the links file into smaller chunks and place them in their own folder
      -  split -l 100 links split/
  -  install nugget
      -  npm i nugget -g
  -  download the links in parallel using nugget
      -  find ./split/ -type f -exec sh -c 'cat {} | xargs nugget -c -d dl' \; &>> dl/download.log
