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

with open(output, 'a') as out:
    with open(filepath, 'r') as input:
        with open(taxid, 'a') as tax_file:
            # counter = 0
            for line in input:
                line = line.split('\t')
                if(len(line) > 3):
                    ntid = line[0]
                    taxid = line[1]
                    tax_file.writelines(ntid + '\t' + taxid + '\n')
                    seq = line[2].rstrip()
                    out.writelines('>' + ntid + '\n')
                    out.writelines(seq + '\n')
                else:
                    with open(logs, 'a+') as logfile:
                        logfile.writelines(ntid + '\n')
