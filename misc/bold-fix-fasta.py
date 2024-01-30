import os
import argparse

parser = argparse.ArgumentParser(description='')
parser.add_argument('--output', type=str)
parser.add_argument('--input', type=str)
parser.add_argument('--taxa', type=str)
parser.add_argument('--log', type=str)
args = parser.parse_args()


filepath = args.input
output = args.output
taxonomy = args.taxa
logs=args.log

info_dict = {}
# get largest seq per ntid
with open(filepath) as input:
    counter = 0
    for line in input:
        if(line.startswith(">")): # awk converts tabs to spaces
            ntid=line.lstrip(">").strip()
        else:
            length = len(line.strip())
            index = counter
            counter += 1
            if length < 100:
                continue
            try:
                if length > info_dict[ntid]['length']:
                    info_dict[ntid] = { 'length': length,
                                        'index': index,
                                        'filename': filepath}
            except KeyError as e:
                    info_dict[ntid] = { 'length': length,
                                        'index': index,
                                        'filename': filepath}

with open(output, 'a') as out:
    with open(filepath, 'r') as input:
            counter = 0
            for line in input:
                if(line.startswith(">")):
                    ntid=line.lstrip(">").rstrip()
                else:
                    seq=line.strip()
                    try:
                        if counter == info_dict[ntid]['index'] and ntid != "*":
                            out.writelines('>' + ntid + '\n')
                            out.writelines(seq + '\n')
                        else:
                            with open(logs, 'a+') as logfile:
                                logfile.writelines(ntid + '\n')
                    except KeyError as e:
                        with open(logs, 'a+') as logfile:
                                logfile.writelines(ntid + '\n')
                    counter += 1


with open(f"{taxonomy}_new", 'a') as out:
    with open(taxonomy, 'r') as input:
        counter = 0
        for line in input:
            linespl = line.split('\t')
            ntid = linespl[0]
            try:
                if counter == info_dict[ntid]['index'] and ntid != "*":
                    tax_path = linespl[1].strip().replace(",", ";").replace("None","NA")
                    out.writelines(ntid + '\t' + tax_path + '\n')
                else:
                    with open(logs, 'a+') as logfile:
                        logfile.writelines(ntid + '\n')
            except KeyError as e:
                with open(logs, 'a+') as logfile:
                        logfile.writelines(ntid + '\n')
            counter += 1


# change domain: sed -i 's/^\([^\t]*\)\t[^\t;]*;/\1\tEukaryota;/' COI-5P.tax.tsv
# remove uncultured on fasta
# awk '
# >     # Load IDs into an associative array
# >     NR==FNR {ids[$0]=1; next}
# > 
# >     # If the line starts with ">", check against the IDs
# >     /^>/ { 
# >         # Extract the ID from the FASTA header
# >         split($0, a, /[>|]/); 
# >         fasta_id=a[2]; 
# > 
# >         # Determine if this entry should be printed
# >         printit = !(fasta_id in ids)
# >     }
# > 
# >     # Print the line if printit is true
# >     {if(printit) print}
# > ' "$id_file" "$fasta_file" > "$temp_fasta"