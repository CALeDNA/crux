import csv

input_file = "COI-5P.tax.tsv"  # Your original TSV file
output_file = "converted_COI-5P.tax.tsv"  # The new TSV file
input_row_count = 0
output_row_count = 0

with open(input_file, 'r') as infile, open(output_file, 'w', newline='') as outfile:
    tsv_reader = csv.reader(infile, delimiter='\t')
    tsv_writer = csv.writer(outfile, delimiter='\t')

    for row in tsv_reader:
        input_row_count += 1

        if len(row) < 2:
            print(f"Skipping malformed row #{input_row_count}: {row}")
            continue

        original_id = row[0]
        taxonomic_path = row[1].split(';')
        smallest_taxonomic_level = None

        # Reverse the taxonomic path and pick the first non-"NA" level
        for taxon in reversed(taxonomic_path):
            if taxon != "NA":
                smallest_taxonomic_level = taxon
                break

        if smallest_taxonomic_level:
            tsv_writer.writerow([smallest_taxonomic_level, original_id])
            output_row_count += 1
        else:
            print(f"No valid taxonomic level found in row #{input_row_count}")

# print(f"Conversion complete. Processed {input_row_count} rows and wrote {output_row_count} rows.")
# print("The output is saved in", output_file)


# taxonkit name2taxid converted_COI-5P.tax.tsv > COI-5P.bold.tax
# awk -F "\t" '!seen[$2]++' COI-5P.bold.tax > COI-5P.bold.tax.unique; mv COI-5P.bold.tax.unique COI-5P.bold.tax
# cut -f2,3 COI-5P.bold.tax > replacement_map.txt; mv replacement_map.txt COI-5P.bold.tax



# 1) replace BOLD ID with Tax ID
def pair_lines(file):
    """Yield a pair of lines from the file at a time."""
    line1 = next(file, None)
    while line1 is not None:
        line2 = next(file, "")
        yield (line1.strip(), line2.strip())
        line1 = next(file, None)

# Replace 'file1.txt', 'file2.txt', and 'file3.txt' with your actual file paths
with open('COI-5P.bold.tax', 'r') as file1, \
     open('COI-5P.tax.tsv', 'r') as file2, \
     open('COI-5P.fasta', 'r') as file3:
    
    with open('COI-5P.tax.tsv_tmp', 'w') as out2, \
         open('COI-5P.fasta_tmp', 'w') as out3:

        # Create an iterator for the third file
        file3_pairs = pair_lines(file3)

        # Iterate through the files
        for line1, line2, (part1, part2) in zip(file1, file2, file3_pairs):
            # line1: entry from file1
            # line2: entry from file2
            # part1, part2: two-line entry from file3

            # Process the lines
            # Example: print them
            #TODO: OUT2 (taxa): line1[1] + '\t' + line2[1]
            #TODO: OUT3 (fasta): '>'+line1[1] + '\n' + part2
            parts=line1.strip().split('\t')
            if len(parts) < 2:
                continue
            taxid=parts[1]
            path=line2.strip().split('\t')[1]
            out2.write(taxid + "\t" + path + '\n')
            out3.write('>' + taxid + '\n')
            out3.write(part2 + '\n')

            # Add your processing logic here

# mv COI-5P.fasta_tmp COI-5P.fasta
# mv COI-5P.tax.tsv_tmp COI-5P.tax.tsv

# 2) de-replicate on unique sequences
unique_sequences = {}
with open('COI-5P.tax.tsv', 'r') as file1, \
     open('COI-5P.fasta', 'r') as file2:
    
    with open('COI-5P.tax.tsv_tmp', 'w') as out1, \
         open('COI-5P.fasta_tmp', 'w') as out2, \
         open('COI-5P_prune.txt', 'w') as out3:
        
        # Create an iterator for the third file
        fasta_pairs = pair_lines(file2)

        # Iterate through the files
        for line1, (part1, part2) in zip(file1, fasta_pairs):
            seq=part2.strip()
            if seq not in unique_sequences:
                out1.write(line1)
                out2.write(part1 + '\n')
                out2.write(part2 + '\n')
            else:
                out3.write(part1.lstrip(">") + '\n')