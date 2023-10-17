import pandas as pd
#NTID TAXPATH
#NTID SEQ

TAXA="Greengene/2022.10.taxonomy.id.tsv"
FASTA="Greengene/greengene.fastv"
FASTA_OUT="Greengene/greengene.fasta"
TAXA_OUT="Greengene/greengene.tsv"

taxadf = pd.read_csv(TAXA, delimiter='\t', dtype={'NTID': str})
fastadf = pd.read_csv(FASTA, delimiter='\t', dtype={'NTID': str})

merged_df = pd.merge(taxadf, fastadf, on=taxadf.columns[0])

merged_df.reset_index(drop=True, inplace=True)


with open(FASTA_OUT, 'w') as file:
        with open(TAXA_OUT, 'w') as file2:
            for index, row in merged_df.iterrows():
                nt_id = row['NTID']
                seq = row['SEQ']
                path= row['TAXPATH']
                file.write(f'>{nt_id}\n{seq}\n')
                file2.write(f'{nt_id}\t{path}\n')

# awk 'NR==FNR { ids[$0]; next } /^>/ { id = substr($0, 2); if (id in ids) skip = 1; else skip = 0 } !skip' Greengene_Bacteria_prune.txt Greengene_Bacteria.fasta2 > Greengene_Bacteria.fasta.tmp