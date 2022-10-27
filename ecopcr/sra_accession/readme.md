# Collecting SRA Accession URLs

### To collect the URLs:
- run sra_accession.py using the following command:
  - python3 sra_accession.py --input "prefixes" --output "links"
- some genbank files are split up into several files - to check which ones:
  - python3 check_chunks.py --input "links" --output "mult"
- to get all of the files that are split up:
  - python3 chunks_size.py --input "mult" --output "chunks"
  - cat "chunks" >> "links"
- to get a file of the format (url,content_length):
  - python3 getsize.py --input "links" --output "linksize"


### To format the URLs:
- split the "linksize" file into smaller chunks (number of VMs * number of cores):
  - python3 split.py --input linksize --output "js2store" --chunks 18 --cores 16
- to sync up to jetstream2 datastore:
  - aws s3 sync js2/ s3://ednaexplorer/urls --endpoint-url https://js2.jetstream-cloud.org:8001/
- to sync down from jetstream2 datastore:
  - aws s3 sync s3://ednaexplorer/urls js2/ --endpoint-url https://js2.jetstream-cloud.org:8001/
