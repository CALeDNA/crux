def process_taxa_files(master_file, taxa_files):
    unique_taxa = {}

    # Iterate through each taxa file
    for file in taxa_files:
        print(f"Reading: {file}")
        with open(file, 'r') as f:
            for line in f:
                taxon, path = line.strip().split('\t')
                # Check if the path is not already in the dictionary
                if path not in unique_taxa:
                    unique_taxa[path] = taxon

    # Write unique taxa to the master file
    with open(master_file, 'w') as mf:
        for path, taxon in unique_taxa.items():
            mf.write(f"{taxon}\t{path}\n")

# Define the master file and the list of taxa files
master_file = 'master_taxa.tax.tsv'
taxa_files = ["12S_MiFish_U/12S_MiFish_U.tax.tsv", "CO1_Metazoa/CO1_Metazoa.tax.tsv", "ITS1_Fungi/ITS1_Fungi.tax.tsv", "UNITE_Fungi/UNITE_Fungi.tax.tsv", "16Smamm/16Smamm.tax.tsv", "CO1_fwhF2_EPTDr2n/CO1_fwhF2_EPTDr2n.tax.tsv", "ITS2_Fungi/ITS2_Fungi.tax.tsv", "rbcL2/rbcL2.tax.tsv", "16s_FishSyn_short/16s_FishSyn_short.tax.tsv", "Cytb_Fish/Cytb_Fish.tax.tsv", "ITS2_Plants/ITS2_Plants.tax.tsv", "trnL_gh/trnL_gh.tax.tsv", "18S_Euk/18S_Euk.tax.tsv", "Greengene_Bacteria/Greengene_Bacteria.tax.tsv", "MC1R/MC1R.tax.tsv", "vert12S/vert12S.tax.tsv"]  # Add the paths to your taxa files here

process_taxa_files(master_file, taxa_files)