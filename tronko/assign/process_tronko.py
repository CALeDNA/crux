import os
import csv
import argparse

def process_arguments():
    parser = argparse.ArgumentParser(description='Process tronko output with mismatch filtering and create ASV table')
    parser.add_argument('--base_dir', type=str, required=True, help='Base directory containing paired, unpaired_F, and unpaired_R directories, usually the marker directory within assign')
    parser.add_argument('--out', type=str, help='Output file as txt or tsv; the log will have the same prefix and end in .log')
    parser.add_argument('--mismatches', type=int, default=5, help='Maximum allowable mismatches')
    parser.add_argument('--project', type=str, required=True, help='Project name that should be the directory that assign is within')
    parser.add_argument('--primer', type=str, required=True, help='Primer name')
    return parser.parse_args()

def getTaxaDict(tronko, allowed_mismatches, mismatch_bins):
    taxaDict = {}
    all_taxa_set = set()
    with open(tronko, 'r') as file:
        header = next(file)
        for current_line in file:
            cols = current_line.strip().split('\t')
            Readname, Taxonomic_Path = cols[0], cols[1]
            all_taxa_set.add(Taxonomic_Path)

            if len(cols) > 2:
                Forward_Mismatch = float(cols[3])
                Reverse_Mismatch = float(cols[4])
                total_mismatch = Forward_Mismatch + Reverse_Mismatch
                placed = False
                for key in mismatch_bins.keys():
                    if type(key) == tuple and key[0] <= total_mismatch <= key[1]:
                        mismatch_bins[key] += 1
                        placed = True
                        break
                if not placed:
                    mismatch_bins["up to Max"] += 1

                if total_mismatch <= allowed_mismatches:
                    taxaDict[Readname] = Taxonomic_Path
                else:
                    taxaDict[Readname] = "Unassigned"
            else:
                taxaDict[Readname] = "Unassigned"
    return taxaDict, all_taxa_set

def getASVDict(asvfile, taxaDict):
    ASVDict = {}
    with open(asvfile, 'r') as file:
        header = next(file).strip().split('\t')
        header.pop(1)  # Remove the 'sequence' column header
        for current_line in file:
            cols = current_line.strip().split('\t')
            Readname, counts = cols[0], cols[2:]
            taxPath = taxaDict.get(Readname, "Unassigned")
            if taxPath in ASVDict:
                currValue = counts
                dictValue = ASVDict[taxPath]
                newValue = [int(element1) + int(element2) for element1, element2 in zip(currValue, dictValue)]
                ASVDict[taxPath] = newValue
            else:
                ASVDict[taxPath] = list(map(int, counts))
    return ASVDict, header

def writeOutput(out, ASVDict, header):
    with open(out, 'w') as output:
        tsv_writer = csv.writer(output, delimiter='\t')
        tsv_writer.writerow(header)
        for taxPath, counts in ASVDict.items():
            row = [taxPath] + list(map(str, counts))
            tsv_writer.writerow(row)

def process_directory(base_dir, subfolder, tronko_suffix, asv_suffix, allowed_mismatches, mismatch_bins):
    folder_name = f"{project_dir}-{os.path.basename(base_dir)}"
    tronko_path = os.path.join(base_dir, subfolder, f"{folder_name}-{tronko_suffix}.txt")
    asv_path = os.path.join(base_dir, subfolder, f"{folder_name}-{asv_suffix}.asv")
    taxaDict, all_taxa_set = getTaxaDict(tronko_path, allowed_mismatches, mismatch_bins)
    ASVDict, header = getASVDict(asv_path, taxaDict)
    return ASVDict, header, all_taxa_set

if __name__ == "__main__":
    args = process_arguments()
    base_dir, out_file, allowed_mismatches, project_dir, primer = args.base_dir, args.out, args.mismatches, args.project, args.primer

    mismatch_bins = {(0, 1): 0, (2, 5): 0, (6, 10): 0, (11, 25): 0, (26, 40): 0, (41, 50): 0, 
                     (51, 60): 0, (61, 70): 0, (71, 80): 0, (81, 90): 0, (91, 100): 0, "up to Max": 0}
    if os.path.exists(os.path.join(base_dir, "paired")):
        paired_ASV, header_P, paired_taxa_set = process_directory(base_dir, "paired", "paired", "paired_F", allowed_mismatches, mismatch_bins)
    else:
        paired_ASV = {}
        header_P = []
        paired_taxa_set = set()
    if os.path.exists(os.path.join(base_dir, "unpaired_F")):
        unpaired_F_ASV, header_F, unpaired_F_taxa_set = process_directory(base_dir, "unpaired_F", "unpaired_F", "unpaired_F", allowed_mismatches, mismatch_bins)
    else:
        unpaired_F_ASV = {}
        header_F = []
        unpaired_F_taxa_set = set()
    if os.path.exists(os.path.join(base_dir, "unpaired_R")):
        unpaired_R_ASV, header_R, unpaired_R_taxa_set = process_directory(base_dir, "unpaired_R", "unpaired_R", "unpaired_R", allowed_mismatches, mismatch_bins)
    else:
        unpaired_R_ASV = {}
        header_R = []
        unpaired_R_taxa_set = set()

    if (len(header_P) > 0):
        first_elem = header_P[0]
    elif (len(header_F) > 0):
        first_elem = header_F[0]
    elif (len(header_R) > 0):
        first_elem = header_R[0]
    else:
        first_elem = ""

    if header_P:
        header_P.pop(0)
    if header_F:
        header_F.pop(0)
    if header_R:
        header_R.pop(0)
    header = list(set(header_P + header_F + header_R))

    total_taxa_unfiltered = len(paired_taxa_set | unpaired_F_taxa_set | unpaired_R_taxa_set)

    ASVDict_combined = {}
    for d, h in [(paired_ASV, header_P), (unpaired_F_ASV, header_F), (unpaired_R_ASV, header_R)]:
        for taxPath, counts in d.items():
            if taxPath in ASVDict_combined:
                currValue = [0] * len(header)
                for i in range(0, len(h)):
                    index = header.index(h[i])
                    currValue[index] = counts[i]
                dictValue = ASVDict_combined[taxPath]
                newValue = [int(element1) + int(element2) for element1, element2 in zip(currValue, dictValue)]
                ASVDict_combined[taxPath] = newValue
            else:
                currValue = [0] * len(header)
                for i in range(0, len(h)):
                    index = header.index(h[i])
                    currValue[index] = counts[i]
                ASVDict_combined[taxPath] = currValue

    total_taxa_assigned = len(ASVDict_combined.keys()) - 1  # Subtract one for "Unassigned"

    header = [first_elem] + header

    writeOutput(out_file, ASVDict_combined, header)
    print(f"Total Taxa (Unfiltered): {total_taxa_unfiltered}")
    print(f"Total Taxa (Assigned with less than {allowed_mismatches} mismatches): {total_taxa_assigned}")

    with open(os.path.join(os.path.dirname(out_file), f"{primer}.log"), 'w') as logfile:
        logfile.write("Mismatch Binning:\n")
        for key, value in mismatch_bins.items():
            if type(key) == tuple:
                range_str = f"{key[0]}-{key[1]}"
            else:
                range_str = key
            logfile.write(f"{range_str}: {value}\n")