import os
import argparse

parser = argparse.ArgumentParser(description='')
parser.add_argument('--output', type=str)
parser.add_argument('--input', type=str)
parser.add_argument('--nucltaxid', type=str)
parser.add_argument('--log', type=str)
args = parser.parse_args()


filepath = args.input
output = args.output
logs=args.log
nucltaxid = args.nucltaxid

info_dict = {}
# get largest seq per ntid
with open(filepath) as infile:
    counter = 0
    multiline=False
    for line in infile:
        if(line.startswith(">")):
            ntid = line.strip(">").rstrip()
            multiline=False
        else:
            if(multiline):
                length += len(line)
            else:
                length = len(line)
                multiline = True
                index = counter
                counter += 1
            if length == 1 or "FISHCARD_" in ntid:
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
        line = line.split()
        ntid = line[1]
        tax_id = line[2]
        if ntid in info_dict:
            taxid_dict[ntid] = tax_id

# replace accid with taxid
with open(output, 'a') as out:
    with open(filepath, 'r') as infile:
        counter = -1
        skip=False
        for line in infile:
            if(line.startswith(">")):
                ntid = line.strip(">").rstrip()
                counter += 1
                try:
                    if(info_dict[ntid]['index'] == counter):
                        taxid=taxid_dict[ntid]
                        out.writelines(f">{taxid}\n")
                        skip=False
                    else:
                        skip=True
                except KeyError as e:
                    with open(logs, 'a+') as logfile:
                        logfile.writelines(ntid + '\n')
                    skip=True
                    pass
            else:
                if not skip:
                    out.writelines(line)
