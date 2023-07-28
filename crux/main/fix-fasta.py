import os
import argparse

parser = argparse.ArgumentParser(description='')
parser.add_argument('--output', type=str)
parser.add_argument('--input', type=str)
parser.add_argument('--log', type=str)
args = parser.parse_args()


filepath = args.input
output = args.output
logs=args.log
taxid = f"{output}.taxid"

info_dict = {}
# get largest seq per ntid
with open(filepath) as input:
    counter = 0
    for line in input:
        line = line.split('\t')
        if(len(line)==1): # awk converts tabs to spaces
            line = line[0].split(' ')
        ntid = line[0]
        length = len(line[2].rstrip())
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
        with open(taxid, 'a') as tax_file:
            counter = 0
            for line in input:
                linespl = line.split('\t')
                ntid = linespl[0]
                try:
                    if(len(linespl) == 3):
                        if counter == info_dict[ntid]['index'] and ntid != "*":
                            taxid = linespl[1]
                            tax_file.writelines(ntid + '\t' + taxid + '\n')
                            out.writelines('>' + ntid + '\n')
                            out.writelines(linespl[2].rstrip() + '\n')
                    else:
                        with open(logs, 'a+') as logfile:
                            logfile.writelines(ntid + '\n')
                except KeyError as e:
                    with open(logs, 'a+') as logfile:
                            logfile.writelines(ntid + '\n')
                counter += 1
