import os
import argparse
import shutil

def process_arguments():
    parser = argparse.ArgumentParser(description='Convert QC fastq files to ASV format')
    parser.add_argument('--dir', type=str, help='Directory path to current asv files')
    parser.add_argument('--old', type=str, help='Directory path of previous tronko assign files')
    parser.add_argument('--projectid', type=str, help='Project ID')
    parser.add_argument('--primer', type=str, help='Primer name')
    parser.add_argument('--paired', action='store_true', help='If directory is for paired files')
    parser.add_argument('--unpairedf', action='store_true', help='If directory is for unpaired_F files')
    parser.add_argument('--unpairedr', action='store_true', help='If directory is for unpaired_R files')

    return parser.parse_args()

def create_dict(dir, old_dir, projectid, primer, suffix="paired_F", isPaired=False):
    if isPaired:
        fastaf=os.path.join(dir, f"{projectid}-{primer}-paired_F.fasta")
        fastar=os.path.join(dir, f"{projectid}-{primer}-paired_R.fasta")
        oldfastaf=os.path.join(old_dir, f"{projectid}-{primer}-paired_F.fasta")
        oldfastar=os.path.join(old_dir, f"{projectid}-{primer}-paired_R.fasta")

        # Create seq dict for old seqs
        old_seq_dict={}
        with open(oldfastaf, 'r') as file_f, open(oldfastar, 'r') as file_r:
            id=""
            for line_f, line_r in zip(file_f, file_r):
                if line_f.startswith(">"):
                    id=line_f.strip().lstrip(">")
                    continue
                else:
                    seq=f"{line_f.strip()},{line_r.strip()}"
                    old_seq_dict.setdefault(seq, id)

        seq_dict={}
        with open(fastaf, 'r') as file_f, open(fastar, 'r') as file_r:
            id=""
            for line_f, line_r in zip(file_f, file_r):
                if line_f.startswith(">"):
                    id=line_f.strip().lstrip(">")
                    continue
                else:
                    seq=f"{line_f.strip()},{line_r.strip()}"
                    if seq not in old_seq_dict.keys():
                        seq_dict.setdefault(id, seq)
        return seq_dict
    else:
        fasta=os.path.join(dir, f"{projectid}-{primer}-{suffix}.fasta")
        oldfasta=os.path.join(old_dir, f"{projectid}-{primer}-{suffix}.fasta")

        # Create seq dict for old seqs
        old_seq_dict={}
        with open(oldfasta, 'r') as file:
            id=""
            for line in file:
                if line.startswith(">"):
                    id=line.strip().lstrip(">")
                    continue
                else:
                    seq=f"{line.strip()}"
                    old_seq_dict.setdefault(seq, id)
        
        seq_dict={}
        with open(fasta, 'r') as file:
            id=""
            for line in file:
                if line.startswith(">"):
                    id=line.strip().lstrip(">")
                    continue
                else:
                    seq=f"{line.strip()}"
                    if seq not in old_seq_dict.keys():
                        seq_dict.setdefault(id, seq)
        return seq_dict


def rewrite_files(seq_dict, dir, projectid, primer, suffix="paired_F", isPaired=False):
    if isPaired:
        fastaf=os.path.join(dir, f"{projectid}-{primer}-paired_F.fasta")
        fastar=os.path.join(dir, f"{projectid}-{primer}-paired_R.fasta")
        asvf=os.path.join(dir, f"{projectid}-{primer}-paired_F.asv")
        asvr=os.path.join(dir, f"{projectid}-{primer}-paired_R.asv")

        # rewrite new fasta files without duplicate sequences
        with open(fastaf, 'r') as file_f, open(fastar, 'r') as file_r:
            with open(f"{fastaf}_tmp", 'w') as out_f, open(f"{fastar}_tmp", 'w') as out_r:
                id=""
                for line_f, line_r in zip(file_f, file_r):
                    if line_f.startswith(">"):
                        id=line_f.strip().lstrip(">")
                        continue
                    else:
                        seq=f"{line_f.strip()},{line_r.strip()}"
                        if id in seq_dict.keys():
                            out_f.write(f">{id}\n")
                            out_r.write(f">{id}\n")
                            out_f.write(f"{seq.split(',')[0]}\n")
                            out_r.write(f"{seq.split(',')[1]}\n")
        shutil.move(f"{fastaf}_tmp", fastaf)
        shutil.move(f"{fastar}_tmp", fastar)

        # rewrite new asv files without duplicate sequences
        with open(asvf, 'r') as file_f, open(asvr, 'r') as file_r:
            with open(f"{asvf}_tmp", 'w') as out_f, open(f"{asvr}_tmp", 'w') as out_r:
                # skip header
                next(file_f)
                next(file_r)
                for line_f, line_r in zip(file_f, file_r):
                    id=line_f.strip().split('\t')[0]
                    if id in seq_dict.keys():
                        out_f.write(line_f)
                        out_r.write(line_r)
        shutil.move(f"{asvf}_tmp", asvf)
        shutil.move(f"{asvr}_tmp", asvr)
    else:
        fasta=os.path.join(dir, f"{projectid}-{primer}-{suffix}.fasta")
        asv=os.path.join(dir, f"{projectid}-{primer}-{suffix}.asv")

        # rewrite new fasta files without duplicate sequences
        with open(fasta, 'r') as file:
            with open(f"{fasta}_tmp", 'w') as out:
                id=""
                for line in file:
                    if line.startswith(">"):
                        id=line.strip().lstrip(">")
                        continue
                    else:
                        seq=f"{line.strip()}"
                        if id in seq_dict.keys():
                            out.write(f">{id}\n")
                            out_f.write(f"{seq}\n")
        shutil.move(f"{fasta}_tmp", fasta)

        # rewrite new asv files without duplicate sequences
        with open(asv, 'r') as file:
            with open(f"{asv}_tmp", 'w') as out:
                # skip header
                next(file)
                for line in file:
                    id=line.strip().split('\t')[0]
                    if id in seq_dict.keys():
                        out.write(line)
        shutil.move(f"{asv}_tmp", asv)


if __name__ == "__main__":
    args = process_arguments()

    dir = args.dir
    old = args.old
    projectid = args.projectid
    primer = args.primer
    isPaired = args.paired
    isUnpairedF = args.unpairedf
    isUnpairedR = args.unpairedr

    print("Deduplicating ASV sequences with previous tronko run...")
    if isPaired:
        seqDict = create_dict(dir, old, projectid, primer, isPaired=True)
        rewrite_files(seqDict, dir, projectid, primer, isPaired=True)
    elif isUnpairedF:
        seqDict = create_dict(dir, old, projectid, primer, suffix="paired_F")
        rewrite_files(seqDict, dir, projectid, primer, suffix="paired_F")
    elif isUnpairedR:
        seqDict = create_dict(dir, old, projectid, primer, suffix="paired_R")
        rewrite_files(seqDict, dir, projectid, primer, suffix="paired_R")
    print("Done!")
