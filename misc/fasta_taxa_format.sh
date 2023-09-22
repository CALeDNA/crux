#! /bin/bash

TAXA="tmp.txt"
FASTA="tmp.fasta"
INPUT="sh_general_release_dynamic_25.07.2023.fasta"

# #UNITE Fungi file format conversion
# while read line; do
#     if [[ "$line" == ">"* ]]
#     then
#         accid=$(echo $line | cut -d"|" -f2)
#         taxa=$(echo $line | cut -d"|" -f5)
#         # levels=$(echo $taxa | cut -d ";")
#         # loop levels:
#         #   remove "*__", if empty replace with "NA" else keep
#         IFS=';' read -ra levels <<< "$taxa"
#         # Loop through the taxa levels
#         for ((i=0; i<${#levels[@]}; i++)); do
#             # Remove "__" including what was before it
#             levels[$i]="${levels[$i]#*__}"
#             # echo "$levels[$i]"
#             # Replace with "NA" if empty
#             if [ -z "${levels[$i]}" ]; then
#                 levels[$i]="NA"
#             fi
#         done
#         # Join the processed taxa levels back into a string with semicolons
#         taxa="$(IFS=';'; echo "${levels[*]}")"

#         echo -e "$accid\t$taxa" >> $TAXA
#         echo ">$accid" >> $FASTA
#     else
#         echo "$line" >> $FASTA
#     fi
# done < $INPUT 
# sed 's/ /\t/' $TAXA > tmp && mv tmp $TAXA



INPUT_TAXA="Greengene/2022.10.taxonomy.id.tsv"
INPUT_FASTA="Greengene/dna-sequences.fasta"
#GREENGENE file format conversion
while IFS=$'\t' read -r accid taxa conf; do
    # loop through taxa, get accid, and search in fasta
    # accid=$(echo $line | cut -f1)
    # taxa=$(echo $line | cut -f2)
    IFS=';' read -ra levels <<< "$taxa"
    # Loop through the taxa levels
    for ((i=0; i<${#levels[@]}; i++)); do
        # Remove "__" including what was before it
        levels[$i]="${levels[$i]#*__}"
        # echo "$levels[$i]"
        # Replace with "NA" if empty
        if [ -z "${levels[$i]}" ]; then
            levels[$i]="NA"
        fi
    done
    # Join the processed taxa levels back into a string with semicolons
    taxa="$(IFS=';'; echo "${levels[*]}")"
    entry=$(awk -v accid="$accid" '$0 ~ accid {print; getline; print; exit}' "$INPUT_FASTA")
    # entry=$(grep -A1 "$accid" "$INPUT_FASTA")
    # Check if grep found anything
    if [ -n "$entry" ]; then
        # If grep found something, save it to the output file
        echo "$entry" >> "$FASTA"
        echo -e "$accid\t$taxa" | tr -d '\n' >> "$TAXA"
    fi
    echo $taxline >> $TAXA
done < $INPUT_TAXA # orig taxa