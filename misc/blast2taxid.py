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

info_dict = {}
# get largest seq per ntid
with open(filepath) as infile:
    counter=0
    for line in infile:
        cols=line.split("\t")
        taxid=cols[1]
        seq=cols[2].rstrip()
        length=len(seq)
        try:
            if length > info_dict[taxid]["length"]:
                info_dict[taxid] = { "length": length,
                                     "index": counter}
        except KeyError:
            info_dict[taxid] = { "length": length,
                                 "index": counter}
        counter+=1


# replace accid with taxid
with open(output, 'a') as out:
    with open(filepath, 'r') as infile:
        counter = 0
        skip=False
        for line in infile:
            cols=line.split("\t")
            taxid=cols[1]
            seq=cols[2].rstrip()
            try:
                if(info_dict[taxid]["index"] == counter):
                    out.writelines(f">{taxid}\n")
                    out.writelines(f"{seq}\n")
            except KeyError:
                print(f"Missing {taxid}")
            counter += 1
