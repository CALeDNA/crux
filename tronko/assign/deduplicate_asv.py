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
    last_id = None
    if isPaired:
        fastaf=os.path.join(dir, f"{projectid}-{primer}-paired_F.fasta")
        fastar=os.path.join(dir, f"{projectid}-{primer}-paired_R.fasta")
        oldfastaf=os.path.join(old_dir, f"{projectid}-{primer}-paired_F.fasta")
        oldfastar=os.path.join(old_dir, f"{projectid}-{primer}-paired_R.fasta")

        # Create seq dict for old seqs
        old_seq_dict={}
        dupl_seq_dict={}
        with open(oldfastaf, 'r') as file_f, open(oldfastar, 'r') as file_r:
            id=""
            for line_f, line_r in zip(file_f, file_r):
                if line_f.startswith(">"):
                    id=line_f.strip().lstrip(">")
                    last_id=line_f.split('_')[-1].strip()
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
                    else:
                        dupl_seq_dict.setdefault(old_seq_dict[seq], seq)
        
        # get new asv occurrences
        asvf=os.path.join(dir, f"{projectid}-{primer}-paired_F.asv")
        asvr=os.path.join(dir, f"{projectid}-{primer}-paired_R.asv")
        with open(asvf, "w") as asvf, open(asvr, "w") as asvr:
            for line_f, line_r in zip(asvf, asvr):
                seqf=line_f.strip().split('\t')[1]
                seqr=line_r.strip().split('\t')[1]
                for key, value in dupl_seq_dict.items():
                    if value == f"{seqf},{seqr}":
                        dupl_seq_dict[key]="\t".join(line_f.strip().split('\t')[2:])
                        break

        # update old asv files with deduplicated occurrences
        oldasvf=os.path.join(old_dir, f"{projectid}-{primer}-paired_F.asv")
        newasvf=os.path.join(old_dir, f"{projectid}-{primer}-paired_F.asv_tmp")
        oldasvr=os.path.join(old_dir, f"{projectid}-{primer}-paired_R.asv")
        newasvr=os.path.join(old_dir, f"{projectid}-{primer}-paired_R.asv_tmp")
        with open(oldasvf, "r") as oasvf, open(oldasvr, "r") as oasvr:
            with open(newasvf, "w") as nasvf, open(newasvr, "w") as nasvr:
                for line_number, (line_f, line_r) in enumerate(zip(oasvf, oasvr)):
                    if line_number == 0:
                        # skip header row
                        continue
                    id=line_f.strip().split('\t')[0]
                    newlinef=line_f
                    newliner=line_r
                    if id in dupl_seq_dict.keys():
                        newlinef+= "\t" + dupl_seq_dict[id]
                        newliner+= "\t" + dupl_seq_dict[id]
                    nasvf.writelines(newlinef)
                    nasvr.writelines(newliner)
        shutil.move(newasvf, oasvf)
        shutil.move(newasvr, oasvr)
        return seq_dict, last_id
    else:
        fasta=os.path.join(dir, f"{projectid}-{primer}-{suffix}.fasta")
        oldfasta=os.path.join(old_dir, f"{projectid}-{primer}-{suffix}.fasta")

        # Create seq dict for old seqs
        old_seq_dict={}
        dupl_seq_dict={}
        with open(oldfasta, 'r') as file:
            id=""
            for line in file:
                if line.startswith(">"):
                    id=line.strip().lstrip(">")
                    last_id=line.split('_')[-1].strip()
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
                    else:
                        dupl_seq_dict.setdefault(old_seq_dict[seq], seq)
        
        # get new asv occurrences
        asv=os.path.join(dir, f"{projectid}-{primer}-{suffix}.asv")
        with open(asv, "w") as asv:
            for line in asv:
                seq=line.strip().split('\t')[1]
                for key, value in dupl_seq_dict.items():
                    if value == seq:
                        dupl_seq_dict[key]="\t".join(line.strip().split('\t')[2:])
                        break

        # update old asv files with deduplicated occurrences
        oldasv=os.path.join(old_dir, f"{projectid}-{primer}-{suffix}.asv")
        newasv=os.path.join(old_dir, f"{projectid}-{primer}-{suffix}.asv_tmp")
        with open(oldasv, "r") as oasv:
            with open(newasv, "w") as nasv:
                for line_number, line in enumerate(oasv):
                    if line_number == 0:
                        # skip header row
                        continue
                    id=line.strip().split('\t')[0]
                    newline=line
                    if id in dupl_seq_dict.keys():
                        newline+= "\t" + dupl_seq_dict[id]
                    nasv.writelines(newline)
        shutil.move(newasv, oasv)
        
        return seq_dict, last_id


def rewrite_files(last_id, seq_dict, dir, projectid, primer, suffix="paired_F", isPaired=False):
    if isPaired:
        fastaf=os.path.join(dir, f"{projectid}-{primer}-paired_F.fasta")
        fastar=os.path.join(dir, f"{projectid}-{primer}-paired_R.fasta")
        asvf=os.path.join(dir, f"{projectid}-{primer}-paired_F.asv")
        asvr=os.path.join(dir, f"{projectid}-{primer}-paired_R.asv")

        # rewrite new fasta files without duplicate sequences
        with open(fastaf, 'r') as file_f, open(fastar, 'r') as file_r:
            with open(f"{fastaf}_tmp", 'w') as out_f, open(f"{fastar}_tmp", 'w') as out_r:
                id=""
                counter = last_id
                for line_f, line_r in zip(file_f, file_r):
                    if line_f.startswith(">"):
                        id=line_f.strip().lstrip(">")
                        continue
                    else:
                        seq=f"{line_f.strip()},{line_r.strip()}"
                        if id in seq_dict.keys():
                            counter+=1
                            # replace with new ID
                            parts = id.split('_')
                            parts[-1] = str(counter)  # Make sure new_id_number is a string
                            id='_'.join(parts)
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
                counter = last_id
                for line_f, line_r in zip(file_f, file_r):
                    id=line_f.strip().split('\t')[0]
                    if id in seq_dict.keys():
                        counter+=1
                        # replace with new ID
                        parts = id.split('_')
                        parts[-1] = str(counter)  # Make sure new_id_number is a string
                        new_id='_'.join(parts)
                        line_f.replace(id, new_id)
                        id.replace("_F_", "_R_")
                        new_id.replace("_F_", "_R_")
                        line_r.replace(id, new_id)
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
                            out.write(f"{seq}\n")
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
        seqDict, last_id = create_dict(dir, old, projectid, primer, isPaired=True)
        rewrite_files(last_id, seqDict, dir, projectid, primer, isPaired=True)
    elif isUnpairedF:
        seqDict, last_id = create_dict(dir, old, projectid, primer, suffix="unpaired_F")
        rewrite_files(last_id, seqDict, dir, projectid, primer, suffix="unpaired_F")
    elif isUnpairedR:
        seqDict, last_id = create_dict(dir, old, projectid, primer, suffix="unpaired_R")
        rewrite_files(last_id, seqDict, dir, projectid, primer, suffix="unpaired_R")
    print("Done!")
