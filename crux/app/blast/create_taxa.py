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
taxid = f"{output}.tax.tsv"

with open(output, 'a') as out:
    with open(filepath, 'r') as input:
        with open(taxid, 'a') as tax_file:
            # counter = 0
            for line in input:
                linespl = line.split('\t')
                ntid = linespl[0]
                if(len(linespl) == 3):
                    taxid = linespl[1]
                    tax_file.writelines(ntid + '\t' + taxid + '\n')
                    out.writelines(line.rstrip() + '\n')
                else:
                    with open(logs, 'a+') as logfile:
                        logfile.writelines(ntid + '\n')
