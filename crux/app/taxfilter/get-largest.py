import os
import argparse

parser = argparse.ArgumentParser(description='')
parser.add_argument('--primer', type=str)
parser.add_argument('--output', type=str)
parser.add_argument('--sam', type=str)
parser.add_argument('--nucltaxid', type=str)
parser.add_argument('--log', type=str)
args = parser.parse_args()


filepath = args.sam
primer = args.primer
output = args.output
logs=args.log
taxid = f"{output}.taxid"
nucltaxid = args.nucltaxid

info_dict = {}
# get largest seq per ntid
with open(filepath) as sam_file:
    counter = 0
    for line in sam_file:
        line = line.split('\t')
        ntid = line[2]
        length = len(line[9])
        index = counter
        counter += 1
        if len(line[9]) == 1:
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

taxid_dict = {}
with open(nucltaxid, 'r') as nucl:
    for line in nucl:
        line = line.split('\t')
        ntid = line[1]
        tax_id = line[2]
        if ntid in info_dict:
            taxid_dict[ntid] = tax_id

with open(output, 'a') as out:
    with open(filepath, 'r') as sam_file:
        with open(taxid, 'a') as tax_file:
            
            counter = 0
            for line in sam_file:
                line = line.split('\t')
                ntid = line[2]
                try:
                    if counter == info_dict[line[2]]['index'] and ntid != "*":
                    	tax_file.writelines(ntid + '\t' + taxid_dict[ntid] + '\n')
                        seq = line[9]
                        out.writelines('>' + ntid + '\n')
                        out.writelines(seq + '\n')
                except KeyError as e:
                    pass
                    with open(logs, 'a+') as logfile:
                        logfile.writelines(ntid + '\n')
                counter += 1
