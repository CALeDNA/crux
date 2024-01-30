#! /bin/bash

# loop through fasta
# 1) check if marker = COI-5P
# 2) parse taxon path: 
# ['superkingdom', 'phylum', 'class', 'order', 'family', 'genus', 'species']
# [0, 1, 2, 3, 4, 6, 7]

fasta_file="bold.fasta"
fasta_out="Fungi.fasta"
taxa_out="Fungi.tax.tsv"

process_sequence() {
    IFS='|' read -r id marker country taxonomy rest <<< "$current_header"
    # Converting taxonomy to an array
    IFS=',' read -r -a taxonomy_array <<< "$taxonomy"
    # Removing subfamily and subspecies
    unset taxonomy_array[5]
    unset taxonomy_array[-1]
    fungi_list=("Ascomycota" "Basidiomycota" "Chytridiomycota" "Glomeromycota" "Myxomycota" "Zygomycota") 
    # Loop through the list and check each item
    for phylum in "${fungi_list[@]}"; do
        if [[ "$phylum" == "${taxonomy_array[1]}" ]]; then
            # Convert the array back to a string, joined by commas
            IFS=',' new_taxonomy=$(printf "%s," "${taxonomy_array[@]}")
            new_taxonomy=${new_taxonomy%,} # Removing the trailing comma

            # remove leading char
            id="${id#>}"

            # append to out files
            echo ">$id" >> $fasta_out
            echo $current_sequence >> $fasta_out
            echo -e "$id\t$new_taxonomy" >> "$taxa_out"
            break
        fi
    done
}

# Read the FASTA file line by line
while IFS= read -r line
do
    if [[ $line == ">"* ]]; then
        # Process the previous sequence
        if [ -n "$current_header" ]; then
            process_sequence
        fi
        # Update the current header and reset the sequence
        current_header=$line
        current_sequence=""
    else
        # Append the line to the current sequence
        current_sequence+=$line
    fi
done < "$fasta_file"

# Process the last sequence in the file
if [ -n "$current_header" ]; then
    process_sequence
fi