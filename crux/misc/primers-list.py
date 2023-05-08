import csv
import re
import os
import argparse

parser = argparse.ArgumentParser(description='')
parser.add_argument('--dir', type=str)
parser.add_argument('--csv', type=str)
parser.add_argument('--primers', type=str)
args = parser.parse_args()


input = args.csv
dir = args.dir
primers = args.primers

with open(input) as csvfile:
    reader = csv.reader(csvfile, delimiter=',')
    # get columns of Markers in header
    for row in reader:
        print(row)
        counter = 0
        indexes = []
        for col in row:
            if ("Marker" in col and re.search(r'\d+$', col)):
                indexes.append(counter)
            counter+=1
        break
    print(indexes)

    # get unique markers
    markers = []
    for row in reader:
        for index in indexes:
            if(row[index] not in markers):
                markers.append(row[index])
    print(markers)

forward_primer=os.path.join(dir,"forward_primers.txt")
reverse_primer=os.path.join(dir,"reverse_primers.txt")
with open(primers) as primerfile:
    with open(forward_primer, 'a+') as forward:
        with open(reverse_primer, 'a+') as reverse:
            reader = csv.reader(primerfile, delimiter=',')

            next(reader, None) # skip header
            for row in reader:
                if(row[1] in markers):
                    forward.writelines(f">{row[1]}\n")
                    forward.writelines(row[2] + '\n')
                    reverse.writelines(f">{row[1]}\n")
                    reverse.writelines(row[3] + '\n')