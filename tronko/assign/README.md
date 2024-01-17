# Project Data README

## Overview
This README file accompanies the downloadable gzip archive, which contains essential data for your project. The archive includes two primary types of data:

1. **Tronko Taxonomic Files**: 
    - These files provide detailed taxonomic information organized by primer and include multiple files with different cutoffs. 
    - All files use a quality score of 30 and cover a range of mismatches, from 1 to 100 mismatches. 
    - This data represents the final output after processing raw sample data through Tronko Assign ([GitHub](https://github.com/lpipes/tronko)). Tronko utilizes a rapid phylogeny-based method for accurate community profiling in large-scale metabarcoding datasets. 
    - Metabarcoding datasets are pre-built using T-REX (Tronko REference libraries using eXisting tools), which involves running in silico PCR (ecopcr) against the WGS and GenBank nucleotide sequence databases hosted on NCBI, followed by processing the output through Blast against the NCBI nucleotide blast database ([NCBI Blast Database](https://ftp.ncbi.nlm.nih.gov/blast/db/)). The dataset is then run through tronko to build the resulting Tronko reference database.
    - The current Tronko reference databases are available [here](https://docs.google.com/spreadsheets/d/15TpmXykc03w6QewDl1XWYyQc4CRMHg7NhiGRHjEtV9Y/edit?usp=sharing).

2. **Terradactyl Remote Sensing Data**: 
    - This dataset includes remote sensing data, compiled from the specified coordinates in the uploaded metadata CSV file (`metabarcoding_metadata_original.csv`), into one comprehensive CSV file (`metabarcoding_metadata_terradactyl.csv`) using Terradactyl. 
    - The Terradactyl output incorporates environmental variables associated with each sampling location and date, sourced from [GBIF](https://www.gbif.org/) and [Google Earth Engine](https://earthengine.google.com/).


## Contents of the Archive
- `tronko/<primer name>/`: Directory containing all taxonomic information, sorted by primer.
  - `*.txt`: ASV files containing the taxonomic path with the corresponding number of mismatches filtered applied.
  - `<primer name>.log`: Mismath binning count overview.
- `terradactyl/`: Directory with remote sensing data.
  - `metabarcoding_metadata_original.csv`: User uploaded metadata csv.
  - `metabarcoding_metadata_terradactyl.csv`: Compiled remote sensing readings from the sample coordinates.

## How to Use the Data
1. **Accessing Files**: The files are organized into directories for ease of access. Use appropriate software to view or analyze the data.
2. **Understanding the Taxonomic Files**: The `tronko/${primer name}/*.txt` provides a list of species in ASV format, where the first column is the taxonomic path and the rest of the columns are the frequency in which it appeared in a given sample.
3. **Interpreting Terradactyl's Remote Sensing Data**: The `terradactyl` directory contains the user uploaded csv with the extra headers removed, and the terradactyl csv file that's used for our site reports. The terradactyl csv contains remote sensing data from Google Earth and GBIF related to the user's samples.

## Support
For any queries or technical assistance, please contact our support team at [help@ednaexplorer.org](mailto:help@ednaexplorer.org).

