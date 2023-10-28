# 1) dict of new sequences
#       - create dict of new (paired?) sequences
#       - key: sequence (paired:<forward>,<reverse>)
#       - value: sequence ID
# 2) loop through old asv files
#       - if old sequence appear in dict
#           - append new data columns to the end of the row
#           - rm seq entry from dict
#       - if old sequence does not appear in dict
#           - append N 0's to the end of row.
# 3) loop through remaining sequences in dictionary
#       - append sequences left in hash map to the bottom of asv
#           - add 0's for the old samples columns
#       - append rows of that sequence ID to the old tronko output
#       - append rows of that sequence ID to the old fasta files
import os
import csv
import argparse

def process_arguments():
    parser = argparse.ArgumentParser(description='Convert QC fastq files to ASV format')
    parser.add_argument('--dir', type=str, help='Directory path to fastq files')
    parser.add_argument('--out', type=str, help='Filepath to output file')
    parser.add_argument('--primer', type=str, help='Primer name')
    parser.add_argument('--projectid', type=str, help='Project ID')
    parser.add_argument('--paired', action='store_true', help='If directory is for paired files')
    parser.add_argument('--unpairedf', action='store_true', help='If directory is for unpaired_F files')
    parser.add_argument('--unpairedr', action='store_true', help='If directory is for unpaired_R files')


def create_seq_dict(filenamef, filenamer=None):
    # create seq dictionary from new ASV files
    seqDict = {} # key: sequence, value: seq ID
    asvDict = {} # key: sequence, value: ASV columns
    if filenamer:
        with open(filenamef, 'r') as filef, open(filenamer, 'r') as filer:
            for current_linef, current_liner in zip(filef, filer):
                current_linef = current_linef.strip()
                current_liner = current_liner.strip()
                if(current_linef == "" or current_liner == ""):
                    continue
                # Split tsv columns
                columnsf = current_linef.split('\t')
                columnsr = current_liner.split('\t')
                
                if len(columnsf) > 1 and len(columnsr) > 1:
                    seqID = columnsf[0]
                    sequencef = columnsf[1]
                    sequencer = columnsr[1]
                    asv_f = '\t'.join(columnsf[2:])
                seqDict.setdefault(f"{sequencef},{sequencer}", seqID)
                asvDict.setdefault(f"{sequencef},{sequencer}", asv_f)
    else:
        with open (filenamef, 'r') as file:
            for current_line in file:
                current_line = current_line.strip()
                if (current_line == ""):
                    continue
                columns = current_line.split('\t')

                if len(columns) > 1:
                    seqID = columns[0]
                    sequence = columns[1]
                    asv = '\t'.join(columns[2:])
                    seqDict.setdefault(sequence, seqID)
                    asvDict.setdefault(sequence, asv)
    return seqDict, asvDict


def create_asv(old_asvf, output_filef, seqDict, asvDict, old_asvr = None, output_filer=None, isPaired=False):
    if isPaired:
        with open(output_filef, 'w') as outputf, open(output_filer, 'w') as outputr:
            tsvwriterf = csv.writer(outputf, delimiter='\t')
            tsvwriterr = csv.writer(outputr, delimiter='\t')
            with open(old_asvf, 'r') as oldasvf, open(old_asvr, 'r') as oldasvr:
                counter = 0
                newFilesCount = len(seqDict["sequence"].split('\t'))
                for linef, liner in zip(oldasvf, oldasvr):
                    columnsf = linef.split('\t')
                    columnsr = liner.split('\t')
                    if counter == 0:
                        header = '\t'.join(columnsf + seqDict["sequence"].split('\t'))
                        tsvwriterf.writerow(header)
                        tsvwriterr.writerow(header)
                        counter += 1
                        continue

                    sequencef = columnsf[1]
                    sequencer = columnsr[1]
                    sequence = f"{sequencef},{sequencer}"
                    if sequence in seqDict:
                        # append new cols
                        newCols = asvDict[sequence]
                        newRowf = '\t'.join(columnsf + newCols)
                        newRowr = '\t'.join(columnsr + newCols)
                        tsvwriterf.writerow(newRowf)
                        tsvwriterr.writerow(newRowr)
                        # delete from seqDict
                        del seqDict[sequence]
                        del asvDict[sequence]
                    else:
                        newCols = [0] * newFilesCount
                        newRowf = '\t'.join(columnsf + newCols)
                        newRowr = '\t'.join(columnsr + newCols)
                        tsvwriterf.writerow(newRowf)
                        tsvwriterr.writerow(newRowr)

    else:
        with open(output_filef, 'w') as output:
            tsvwriter = csv.writer(output, delimiter='\t')
            with open(old_asvf, 'r') as oldasv:
                counter = 0
                newFilesCount = len(seqDict["sequence"].split('\t'))
                for line in oldasv:
                    columns = line.split('\t')
                    if counter == 0:
                        header = '\t'.join(columns + seqDict["sequence"].split('\t'))
                        tsvwriter.writerow(header)
                        counter += 1
                        continue

                    sequence = columns[1]
                    if sequence in seqDict:
                        # append new cols
                        newCols = asvDict[sequence]
                        newRow = '\t'.join(columns + newCols)
                        tsvwriter.writerow(newRow)
                        # delete from seqDict
                        del seqDict[sequence]
                        del asvDict[sequence]
                    else:
                        newCols = [0] * newFilesCount
                        newRow = '\t'.join(columns + newCols)
                        tsvwriter.writerow(newRow)
    return seqDict, asvDict


def update_fasta(old_fastaf, seqDict, old_fastar=None, isPaired=False):
    if isPaired:
        # get current ID
        with open(old_fastaf, 'r') as fasta_file:
            previous_line = ""
            for current_line in fasta_file:
                if current_line.strip():  # Check if the line is not empty or just whitespace
                    seq_id = previous_line
                previous_line = current_line
            currentID = int(seq_id.split("_F_", 1)[1]) + 1
        with open(old_fastaf, 'w') as fasta_filef, open(old_fastar, 'w') as fasta_filer:
            for sequence, seq_id in seqDict.items():
                seq_id = seq_id.split("_F_")[0] + f"_F_{currentID}"
                fasta_filef.write(f">{seq_id}" + "\n")
                fasta_filef.write(sequence + '\n')
                seq_id = seq_id.split("_F_")[0] + f"_R_{currentID}"
                fasta_filer.write(f">{seq_id}" + "\n")
                fasta_filer.write(sequence + '\n')
                currentID += 1
    elif old_fastar:
        # get current ID
        with open(old_fastar, 'r') as fasta_file:
            previous_line = ""
            for current_line in fasta_file:
                if current_line.strip():  # Check if the line is not empty or just whitespace
                    seq_id = previous_line
                previous_line = current_line
            currentID = int(seq_id.split("_R_", 1)[1]) + 1
        with open(old_fastar, 'w') as fasta_file:
            for sequence, seq_id in seqDict.items():
                seq_id = seq_id.split("_F_")[0] + f"_R_{currentID}"
                currentID += 1
                fasta_file.write(f">{seq_id}" + '\n')
                fasta_file.write(sequence + '\n')

    else:
        # get current ID
        with open(old_fastaf, 'r') as fasta_file:
            previous_line = ""
            for current_line in fasta_file:
                if current_line.strip():  # Check if the line is not empty or just whitespace
                    seq_id = previous_line
                previous_line = current_line
            currentID = int(seq_id.split("_F_", 1)[1]) + 1
        with open(old_fastaf, 'w') as fasta_file:
            for sequence, seq_id in seqDict.items():
                seq_id = seq_id.split("_F_")[0] + f"_F_{currentID}"
                currentID += 1
                fasta_file.write(f">{seq_id}" + '\n')
                fasta_file.write(sequence + '\n')


# 3) loop through remaining sequences in dictionary
#       - append sequences left in hash map to the bottom of asv
#           - add 0's for the old samples columns
#       - append rows of that sequence ID to the old tronko output
#       - append rows of that sequence ID to the old fasta files
def update_tronko(old_output, curr_output, seqDict, asvDict):
    # get current ID
    previous_line = ""
    for current_line in old_output:
        if current_line.strip():  # Check if the line is not empty or just whitespace
            seq_id = previous_line
        previous_line = current_line
    currentID = int(seq_id.split("_R_", 1)[1]) + 1
    with open(old_output, 'w') as oldoutput:
        for sequence, seq_id in seqDict.items():
            seq_id = seq_id.split("_F_")[0] + f"_F_{currentID}"
            currentID += 1
            currOutputID = asvDict[sequence]
            currOutputLine = ""
            with open(curr_output, 'r') as curroutput:
                for line in curroutput:
                    if currOutputID in line:
                        currOutputLine = line.strip()
                        break
                else:
                    print(f"{currOutputID} was not found in {curr_output}")
            currOutputLine = '\t'.join([seq_id] + currOutputLine.split('\t')[1:])
            oldoutput.write(currOutputLine + '\n')

if __name__ == "__main__":
    args = process_arguments()

    dir = args.dir
    out = args.out
    primer = args.primer
    projectid = args.projectid
    isPaired = args.paired
    isUnpairedF = args.unpairedf
    isUnpairedR = args.unpairedr

    if isPaired:
        filenamef = os.path.join(dir, f"{projectid}-{primer}-paired_F.asv")
        filenamer = os.path.join(dir, f"{projectid}-{primer}-paired_R.asv")
        seqDict, asvDict = create_seq_dict(filenamef, filenamer)

        outputf = os.path.join(dir, f"{projectid}-{primer}-paired_F.asv.new")
        outputr = os.path.join(dir, f"{projectid}-{primer}-paired_R.asv.new")
        seqDict, asvDict = create_asv(filenamef, outputf, seqDict, asvDict, old_asvr = filenamer, output_filer=outputr, isPaired=True)

        fastaf = os.path.join(dir, f"{projectid}-{primer}-paired_F.fasta")
        fastar = os.path.join(dir, f"{projectid}-{primer}-paired_R.fasta")
        update_fasta(fastaf, seqDict, old_fastar=fastar, isPaired=True)

        old_tronko = os.path.join(dir, f"{projectid}-{primer}-paired.txt")
        curr_tronko = os.path.join(dir, f"{projectid}-{primer}-paired.txt.current")
        update_tronko(old_tronko, curr_tronko, seqDict, asvDict)
        
    elif isUnpairedF:
        filename = os.path.join(dir, f"{projectid}-{primer}-unpaired_F.asv")
        seqDict, asvDict = create_seq_dict(filename)

        output = os.path.join(dir, f"{projectid}-{primer}-unpaired_F.asv.new")
        seqDict, asvDict = create_asv(filename, output, seqDict, asvDict)

        fasta = os.path.join(dir, f"{projectid}-{primer}-unpaired_F.fasta")
        update_fasta(fasta, seqDict)

        old_tronko = os.path.join(dir, f"{projectid}-{primer}-unpaired_F.txt")
        curr_tronko = os.path.join(dir, f"{projectid}-{primer}-unpaired_F.txt.current")
        update_tronko(old_tronko, curr_tronko, seqDict, asvDict)
        
    else:
        filename = os.path.join(dir, f"{projectid}-{primer}-unpaired_R.asv")
        seqDict, asvDict = create_seq_dict(filename)

        output = os.path.join(dir, f"{projectid}-{primer}-unpaired_R.asv.new")
        seqDict, asvDict = create_asv(filename, output, seqDict, asvDict)

        fasta = os.path.join(dir, f"{projectid}-{primer}-unpaired_R.fasta")
        update_fasta(fasta, seqDict)

        old_tronko = os.path.join(dir, f"{projectid}-{primer}-unpaired_R.txt")
        curr_tronko = os.path.join(dir, f"{projectid}-{primer}-unpaired_R.txt.current")
        update_tronko(old_tronko, curr_tronko, seqDict, asvDict)