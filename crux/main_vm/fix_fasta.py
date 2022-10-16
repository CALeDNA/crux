import os
import argparse

parser = argparse.ArgumentParser(description='')
parser.add_argument('--output', type=str)
parser.add_argument('--fasta', type=str)
parser.add_argument('--nucltaxid', type=str)
parser.add_argument('--log', type=str)
args = parser.parse_args()


filepath = args.fasta
output = args.output
logs=args.log
taxid = f"{output}.taxid"
nucltaxid = args.nucltaxid

info_dict = {}
# get largest seq per ntid
with open(filepath) as fasta:
    skip=False
    counter = -1
    for line in fasta:
        counter+=1
        if line.startswith('>'):
            if line.strip('>').rstrip('\n') in info_dict:
                skip=True
                continue
            else:
                ntid=line.strip('>').rstrip('\n')
                skip=False
                continue
        if not skip:
            length = len(line)
            index = counter
            try:
                if length > info_dict[ntid]['length']:
                    info_dict[ntid] = { 'length': length,
                                        'index': index,
                                        'filename': filepath}
            except KeyError:
                    info_dict[ntid] = { 'length': length,
                                        'index': index,
                                        'filename': filepath}

print(len(info_dict))
taxid_dict = {}
with open(nucltaxid, 'r') as nucl:
    for line in nucl:
        line = line.split('\t')
        ntid = line[1]
        tax_id = line[2]
        if ntid in info_dict:
            taxid_dict[ntid] = tax_id
print(len(taxid_dict))

with open(output, 'a+') as out:
    with open(filepath, 'r') as fasta:
        with open(taxid, 'a+') as tax_file:
            skip=False
            counter = 0
            for line in fasta:
                counter+=1
                if line.startswith('>'):
                    ntid=line.strip('>').rstrip('\n')
                    try:
                        skip=True
                        if counter == info_dict[ntid]['index']:
                            tax_file.writelines(ntid + '\t' + taxid_dict[ntid] + '\n')
                            out.writelines(line)
                            skip=False
                            continue
                    except KeyError as e:
                        with open(logs, 'a+') as logfile:
                            logfile.writelines(ntid + '\n')
                        continue
                if not skip:
                    out.writelines(line)

