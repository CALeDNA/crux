import csv
import argparse

def process_arguments():
    parser = argparse.ArgumentParser(description='Convert tronko output to taxanomy ASV format')
    parser.add_argument('--tronko', type=str, help='Path to tronko output file')
    parser.add_argument('--asv', type=str, help='Path to tronko\'s sequence ASV file')
    parser.add_argument('--out', type=str, help='Output file path')

    return parser.parse_args()


def getTaxaDict(tronko):
    taxaDict = {}
    skippedHeader = False
    with open(tronko, 'r') as file:
        for current_line in file:
            # skip header
            if not skippedHeader:
                skippedHeader = True
                continue
            cols=current_line.strip().split('\t')
            # key: readname
            # value: tax path
            taxaDict[cols[0]] = cols[1]
    return taxaDict


def getASVDict(asvfile, taxaDict):
    ASVDict = {}
    skippedHeader = False
    header=""
    with open(asvfile, 'r') as file:
        for current_line in file:
            # skip header
            if not skippedHeader:
                header=current_line.strip().split('\t')
                del header[1]
                header[0]="taxonomy"
                skippedHeader = True
                continue
            cols=current_line.strip().split('\t')
            readName=cols[0]
            taxPath=taxaDict[readName]
            #ASVDict
            # key: taxPath
            # value: ASV int columns
            if taxPath in ASVDict:
                currValue=cols[2:]
                dictValue=ASVDict[taxPath]
                newValue=[int(element1) + int(element2) for element1, element2 in zip(currValue, dictValue)]
                print(newValue)
                ASVDict.setdefault(taxPath,newValue)
            else:
                ASVDict[taxPath]=cols[2:]
    return ASVDict, header


def writeOutput(out, ASVDict, header):
    with open(out, 'w') as output:
        tsv_writer=csv.writer(output,delimiter='\t')
        tsv_writer.writerow(header)

        for taxPath, cols in ASVDict.items():
            row=[taxPath] + cols
            tsv_writer.writerow(row)



if __name__ == "__main__":
    args = process_arguments()

    tronko=args.tronko
    seqASV=args.asv
    out=args.out


    taxaDict = getTaxaDict(tronko=tronko)
    ASVDict, header = getASVDict(seqASV, taxaDict)

    writeOutput(out, ASVDict, header)
