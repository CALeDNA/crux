# 1) cat all fastq files per primer
#       - for paired: once for forward and again separately for reverse
# 2) loop through master fastq files and create hashmap
#       - key: sequence
#       - value: list of len(fastq files) 0's
# 3) keep hashmap. loop through original fastq files sequences
#       - find seq in hashmap
#       - add one to hashmap(seq)[index]
import os
import gzip
import shutil
import csv
import argparse

def process_arguments():
    parser = argparse.ArgumentParser(description='Convert QC fastq files to ASV format')
    parser.add_argument('--dir', type=str, help='Directory path to fastq files')
    parser.add_argument('--out', type=str, help='Filepath to output file')
    parser.add_argument('--primer', type=str, help='Primer name')
    parser.add_argument('--paired', action='store_true', help='If directory is for paired files')
    parser.add_argument('--unpairedf', action='store_true', help='If directory is for unpaired_F files')
    parser.add_argument('--unpairedr', action='store_true', help='If directory is for unpaired_R files')

    return parser.parse_args()

def is_gzipped(file_path):
    with open(file_path, 'rb') as file:
        return file.read(2) == b'\x1f\x8b'  # Check if the first two bytes are the gzip magic number

def gunzip_file(source_path, target_path):
    with gzip.open(source_path, 'rb') as gz_file:
        with open(target_path, 'wb') as file:
            shutil.copyfileobj(gz_file, file)
    shutil.move(target_path, source_path)

def concatenate_files(directory_path, output_file, suffix):
    counter=0
    with open(output_file, 'w') as output:
        for filename in sorted(os.listdir(directory_path)):
            file_path = os.path.join(directory_path, filename)
            if os.path.isfile(file_path):  # Check if the item is a file (not a subdirectory)
                if file_path.endswith(suffix):
                    if is_gzipped(file_path):
                        gunzipped_file_path = os.path.splitext(file_path)[0] + "_tmp"
                        gunzip_file(file_path, gunzipped_file_path)
                    with open(file_path, 'r') as file:
                        counter+=1
                        output.write(file.read())
                    output.write('\n')  # Add a newline after each file content
    return counter

def create_seq_dict_keys(size, filenamef, filenamer=None,):
    seqDict = {} # key: sequence, value: list of len(fastq files) 0's
    if filenamer:
        with open(filenamef, 'r') as filef, open(filenamer, 'r') as filer:
                previous_linef = ""  # Initialize an empty string to store the previous line
                previous_liner = ""  # Initialize an empty string to store the previous line
                for current_linef, current_liner in zip(filef, filer):
                    current_linef = current_linef.strip()
                    current_liner = current_liner.strip()
                    if(current_linef == "" or current_liner == ""):
                        continue

                    if previous_linef.startswith("@") and previous_liner.startswith("@"):
                        seqDict.setdefault(f"{current_linef},{current_liner}", [0 for _ in range(size)])
                    
                    previous_linef = current_linef
                    previous_liner = current_liner
        os.remove(filenamef)
        os.remove(filenamer)
    else:
        with open(filenamef, 'r') as file:
            previous_line = ""  # Initialize an empty string to store the previous line

            for current_line in file:
                current_line = current_line.strip()  # Remove leading/trailing whitespace, if needed

                if previous_line.startswith("@"):
                    # Add sequence to dictionary
                    seqDict.setdefault(current_line, [0 for _ in range(size)]) 

                # Update the previous_line variable with the current line for the next iteration
                previous_line = current_line
        # Delete tmp file
        os.remove(filenamef)
    return seqDict

def create_seq_dict_values(directory_path, seqDict, suffix, isPaired=False):
    index=0
    if isPaired:
        for filename in sorted(os.listdir(directory_path)):
            file_path = os.path.join(directory_path, filename)
            if os.path.isfile(file_path):  # Check if the item is a file (not a subdirectory)
                if file_path.endswith(suffix):
                    # remove suffix and open both files
                    file_path = file_path[:-len(suffix)]
                    # Get all files that begin with the modified 'file_path'
                    paired_files = [os.path.join(directory_path, filename) for filename in sorted(os.listdir(directory_path)) if os.path.basename(file_path) in filename]
                    with open(paired_files[0], 'r') as filef, open(paired_files[1], 'r') as filer:
                        previous_linef = ""  # Initialize an empty string to store the previous line
                        previous_liner = ""  # Initialize an empty string to store the previous line

                        for current_linef, current_liner in zip(filef, filer):
                            current_linef = current_linef.strip()
                            current_liner = current_liner.strip()
                            if(current_linef == "" or current_liner == ""):
                                continue
                            if previous_linef.startswith("@") and previous_liner.startswith("@"):
                                seqDict[f"{current_linef},{current_liner}"][index] += 1
                            previous_linef = current_linef
                            previous_liner = current_liner
                    index+=1

    else:
        for filename in sorted(os.listdir(directory_path)):
            file_path = os.path.join(directory_path, filename)
            if os.path.isfile(file_path):  # Check if the item is a file (not a subdirectory)
                if file_path.endswith(suffix):
                    with open(file_path, 'r') as file:
                        previous_line = ""

                        for current_line in file:
                            current_line = current_line.strip()  # Remove leading/trailing whitespace, if needed
                            if previous_line.startswith("@"):
                                # increase count in seqDict
                                seqDict[current_line][index] += 1 # add one to number of occurences

                            # Update the previous_line variable with the current line for the next iteration
                            previous_line = current_line
                    index+=1
    return seqDict

def create_asv(directory_path, output_file, primer, suffix, type, seqDict, isPaired=False):
    fasta_file = ""
    file_path, old_ext = os.path.splitext(output_file)
    if old_ext != ".fasta":
        fasta_file = file_path + ".fasta"
    else:
        fasta_file = output_file
        output_file = file_path + ".txt"
    
    if isPaired:
        output_filef=""
        output_filer=""
        fasta_filer=""
        fasta_filer=""
        typef=type
        typer=type.replace("F","R")
        if "paired_R" in output_file:
            output_filer = output_file
            fasta_filer = fasta_file
            output_filef = output_file.replace("paired_R","paired_F")
            fasta_filef = fasta_file.replace("paired_R","paired_F")
        elif "paired_F" in output_file:
            output_filef = output_file
            fasta_filef = fasta_file
            output_filer = output_file.replace("paired_F","paired_R")
            fasta_filer = fasta_file.replace("paired_F","paired_R")
        
        if output_filef != "" and output_filer != "":
            with open(output_filef, 'w') as outputf, open(output_filer, 'w') as outputr:
                with open(fasta_filef, 'w') as fasta_outputf, open(fasta_filer, 'w') as fasta_outputr:
                    # create header
                    headerf=[f"{primer}_seq_number", "sequence"]
                    headerr=[f"{primer}_seq_number", "sequence"]
                    for filename in sorted(os.listdir(directory_path)):
                        tsv_writerf = csv.writer(outputf, delimiter='\t')
                        tsv_writerr = csv.writer(outputr, delimiter='\t')
                        if filename.endswith(suffix):
                            headerf.append(filename[:-len(suffix)])
                        else:
                            headerr.append(filename[:-len(suffix)])
                    tsv_writerf.writerow(headerf)
                    tsv_writerr.writerow(headerr)
                    counter=0
                    for key, value in seqDict.items():
                        rowf=[]
                        rowr=[]
                        rowf.append(f"{primer}_{typef}_{counter}")
                        rowr.append(f"{primer}_{typer}_{counter}")
                        fasta_outputf.write(f">{primer}_{typef}_{counter}\n")
                        fasta_outputr.write(f">{primer}_{typer}_{counter}\n")
                        rowf.append(key.split(",")[0])
                        rowr.append(key.split(",")[1])
                        for elem in value:
                            rowf.append(elem)
                            rowr.append(elem)
                        tsv_writerf.writerow(rowf)
                        tsv_writerr.writerow(rowr)
                        fasta_outputf.write(key.split(",")[0]+"\n")
                        fasta_outputr.write(key.split(",")[1]+"\n")
                        counter+=1

    else:
        with open(output_file, 'w') as output:
            with open(fasta_file, 'w') as fasta_output:
                # create header
                header=[f"{primer}_seq_number", "sequence"]
                for filename in sorted(os.listdir(directory_path)):
                    tsv_writer = csv.writer(output, delimiter='\t')
                    if filename.endswith(suffix):
                        header.append(filename[:-len(suffix)])
                # output.write(header)
                tsv_writer.writerow(header) # check if writing correctly
                counter=0
                for key, value in seqDict.items():
                    row=[]
                    row.append(f"{primer}_{type}_{counter}")
                    fasta_output.write(f">{primer}_{type}_{counter}\n")
                    row.append(key)
                    for elem in value:
                        row.append(elem)
                    tsv_writer.writerow(row)
                    fasta_output.write(key+"\n")
                    counter+=1

if __name__ == "__main__":
    args = process_arguments()

    dir = args.dir
    out = args.out
    primer = args.primer
    isPaired = args.paired
    isUnpairedF = args.unpairedf
    isUnpairedR = args.unpairedr

    if isPaired:
        suffix="_F_filt.fastq.gz"
        concatenate_files(dir, f"{out}_tmpf", suffix)
        suffix="_R_filt.fastq.gz"
        fileCount = concatenate_files(dir, f"{out}_tmpr", suffix)
        
        seqDict = create_seq_dict_keys(fileCount, f"{out}_tmpf", filenamer=f"{out}_tmpr")
        seqDict = create_seq_dict_values(dir, seqDict, suffix, isPaired=True)
        create_asv(dir, out, primer, suffix, "paired_F", seqDict, isPaired=True)
    elif isUnpairedF:
        suffix="_F_filt.fastq.gz"
        fileCount = concatenate_files(dir, f"{out}_tmp", suffix)
        seqDict = create_seq_dict_keys(fileCount, f"{out}_tmp")
        seqDict = create_seq_dict_values(dir, seqDict, suffix)
        create_asv(dir, out, primer, suffix, "unpaired_F", seqDict)
    elif isUnpairedR:
        suffix="_R_filt.fastq.gz"
        fileCount = concatenate_files(dir, f"{out}_tmp", suffix)
        seqDict = create_seq_dict_keys(fileCount, f"{out}_tmp")
        seqDict = create_seq_dict_values(dir, seqDict, suffix)
        create_asv(dir, out, primer, suffix, "unpaired_R", seqDict)

    print("ASV complete!")
