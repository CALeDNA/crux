# Project Data README

## Overview
This README file accompanies the downloadable gzip archive, which contains essential data for your project. The archive includes two primary types of data:

1. **Tronko Taxonomic Data**: 
    - **Taxonomic Information**: The files include taxonomic data organized by primer, with multiple files featuring different sequence mismatch thresholds, ranging from 1 to 100 mismatches.
    - **Data Source and Processing**: This data is derived from the user's raw sample data processed through tronko-assign, a tool available on [GitHub](https://github.com/lpipes/tronko). It employs the [Needleman-Wunsch Algorithm](https://github.com/noporpoise/seq-align) for semi-global alignments and [bwa](https://github.com/lh3/bwa) for alignment to leaf nodes.
    - **Reference Tree Creation**: The reference trees used by tronko-assign are generated by tronko-build, through a multi-step pipeline:
      1. **Ecopcr**: Conducting in silico PCR against the [WGS](https://www.ncbi.nlm.nih.gov/Traces/wgs) and [Genbank](https://ftp.ncbi.nlm.nih.gov/genbank) nucleotide sequence databases hosted on NCBI.
      2. **Blast Processing**: Processing ecopcr output using Blast against the [NCBI nucleotide blast database](https://ftp.ncbi.nlm.nih.gov/blast/db/).
      3. **De-replication of Blast Output**: Sorting the resulting reads by length and de-replicating by selecting the longest sequence per NCBI accession version number. eDNAExplorer's available blast reference databases can be downloaded [here](https://doi.org/10.5281/zenodo.10049247).
      4. **AncestralClust**: Clustering the reference database using AncestralClust, which constructs phylogenetic trees to group sequences based on genetic distances. More information is available on [GitHub](https://github.com/lpipes/AncestralClust).
      5. **Tronko-build Formatting**: Adjusting AncestralClust clusters into the formats required by tronko-build, such as MSA fasta files and Newick formatted trees.
      6. **Tronko Reference Tree Generation**: Using tronko-build to create the final reference tree for tronko-assign. Tronko is a method that combines alignment-based and composition-based approaches to calculate the lowest common ancestor (LCA) using data from leaf nodes in a phylogeny. Its advantage lies in storing fractional likelihoods in all nodes of a phylogeny and determining the LCA based on all nodes in the tree.
    - **Access to Tronko Reference Databases**: The latest list of available Tronko reference database for use in eDNAExplorer is available [here](https://docs.google.com/spreadsheets/d/15TpmXykc03w6QewDl1XWYyQc4CRMHg7NhiGRHjEtV9Y/edit?usp=sharing).


2. **Terradactyl Remote Sensing Data**: 
    - This dataset (`metabarcoding_metadata_terradactyl.csv`) includes remote sensing data obtained using Terradactyl, and associated with the specified coordinates and dates in the uploaded metadata CSV file (`metabarcoding_metadata_original.csv`).
    - The Terradactyl output incorporates environmental variables associated with each sampling location and date, sourced from [Google Earth Engine](https://earthengine.google.com/).  For a given coordinate Terradactyl will aggregate cloud-free data environmental data in the 6 months leading up to a sample date within a designated buffer area surrounding each sample location.  The radius of this buffer is defined by the GPS uncertainty associated with a given coordinate, or if this is missing it will default to 30 meters.  The map layers used in Terradactyl are as follows:
    - BioClim data.  The BioClim dataset has 19 bands representing different measures of temperature and precipitation to a resolution of 30 arc seconds (1 kilometer).
    - Soil properties.  Soil data is available at 250 meter resolution from OpenLandMap datasets. We are selecting the values at surface level (band b0) but other bands correspond to depths of 10, 30, 60, 100, and 200 centimeters. 
    - Terrain.  Elevation data for the United States is available from the Shuttle Radar Topography Mission (https://developers.google.com/earth-engine/datasets/catalog/CGIAR_SRTM90_V4) at a resolution of 10 meters. Slope and aspect datasets are derived from elevation data. 
    - Human Influence Index.  Data for the CSP gHM: Global Human Modification is derived from the global Human Modification dataset. Which provides a cumulative measure of human modification of terrestrial lands globally at 1 square-kilometer resolution. The gHM values range from 0.0-1.0 and are calculated by estimating the proportion of a given location (pixel) that is modified, the estimated intensity of modification associated with a given type of human modification or "stressor". 5 major anthropogenic stressors circa 2016 were mapped using 13 individual datasets: human settlement (population density, built-up areas), agriculture (cropland, livestock), transportation (major, minor, and two-track roads; railroads), mining and energy production, electrical infrastructure (power lines, nighttime lights)
    - Landsat 8.  Datasets derived from composite Landsat 8 satellite imagery, taken about every 2 weeks at a 30 meter resolution, include normalized difference vegetation index (NDVI link text), enhanced vegetation index (EVI link text), normalized burn ratio thermal (NBRT link text), and greenest pixel.
    - Sentinel 2.  The Sentinel 2 satellites continuously take multi-spectral imagery of the Earth, covering a given location once every 5 days on average since 2015. Resolution is 10, 20, or 60 meters depending on the band.  This data needs a few preprocessing steps. Because this dataset is huge with tens of thousands of images, using all of them would be very slow. We filter to a date range and filter out images with more than 20% cloudy pixels.
    - Population density and structure.  Modeled population totals, as well as populations split by sex and age brackets, per hectare. This data is modeled for 2020 and described in detail here. We convert population data from density per hectare to per square kilometer.
    - Potential distribution of biomes.  Potential Natural Vegetation biomes global predictions of classes (based on predictions using the BIOMES 6000 dataset's 'current biomes' category.).  Potential Natural Vegetation (PNV) is the vegetation cover in equilibrium with climate that would exist at a given location non-impacted by human activities. 
    - Accessibility to Healthcare.  This global accessibility map enumerates land-based travel time (in minutes) to the nearest hospital or clinic for all areas between 85 degrees north and 60 degrees south for a nominal year 2019. It also includes "walking-only" travel time, using non-motorized means of transportation only.
    - Global Friction Surface.  This global friction surface enumerates land-based travel speed for all land pixels between 85 degrees north and 60 degrees south for a nominal year 2019. It also includes "walking-only" travel speed, using non-motorized means of transportation only. 
    - Light pollution.  Monthly average radiance composite images using nighttime data from the Visible Infrared Imaging Radiometer Suite (VIIRS) Day/Night Band (DNB).
    - Global SRTM CHILI (Continuous Heat-Insolation Load Index).  CHILI is a surrogate for effects of insolation and topographic shading on evapotranspiration represented by calculating insolation at early afternoon, sun altitude equivalent to equinox.
    - Global SRTM Landforms.  The SRTM Landform dataset provides landform classes created by combining the Continuous Heat-Insolation Load Index (SRTM CHILI) and the multi-scale Topographic Position Index (SRTM mTPI) datasets.
    - Potential Fraction of Absorbed Photosynthetically Active Radiation (FAPAR) Monthly.  Potential Natural Vegetation FAPAR predicted monthly median (based on PROB-V FAPAR 2014-2017).
    - Monthly precipitation.  Monthly precipitation in mm at 1 km resolution based on SM2RAIN-ASCAT 2007-2018, IMERG, CHELSA Climate, and WorldClim.
    - Ecoregions and realms.  The RESOLVE Ecoregions dataset, updated in 2017, offers a depiction of the 846 terrestrial ecoregions that represent our living planet.
    - Watersheds.  HydroSHEDS is a mapping product that provides hydrographic information for regional and global-scale applications in a consistent format.
    - World Database on Protected Areas.  The World Database on Protected Areas (WDPA) is the most up-to-date and complete source of information on protected areas, updated monthly with submissions from governments, non-governmental organizations, landowners, and communities. It is managed by the United Nations Environment Programme's World Conservation Monitoring Centre (UNEP-WCMC) with support from IUCN and its World Commission on Protected Areas (WCPA).
    - GFW (Global Fishing Watch) Daily Fishing Hours.  This dataset describes fishing effort, measured in hours of inferred fishing activity.
    - HYCOM: Hybrid Coordinate Ocean Model, Water Temperature and Salinity.  The Hybrid Coordinate Ocean Model (HYCOM) is a data-assimilative hybrid isopycnal-sigma-pressure (generalized) coordinate ocean model.
    - Ocean Color SMI: Standard Mapped Image MODIS Aqua Data.  This dataset may be used for studying the biology and hydrology of coastal zones, changes in the diversity and geographical distribution of coastal marine habitats, biogeochemical fluxes and their influence in Earth's oceans and climate over time, and finally the impact of climate and environmental variability and change on ocean ecosystems and the biodiversity they support.


## Contents of the Archive
- `tronko/<primer name>/`: Directory containing all taxonomic information, sorted by primer.
  - `*.txt`: ASV files containing the taxonomic path with the corresponding number of mismatches filtered applied.
  - `<primer name>.log`: Mismath binning count overview.
- `terradactyl/`: Directory with remote sensing data.
  - `metabarcoding_metadata_original.csv`: User uploaded metadata csv.
  - `metabarcoding_metadata_terradactyl.csv`: Compiled remote sensing readings from the sample coordinates.

## How to Use the Data
1. **Accessing Files**: The files are organized into directories for ease of access. Use appropriate software to view or analyze the data.
2. **Understanding the Taxonomic Files**: The `tronko/${primer name}/*.txt` provides a list of species in ASV format, where the first column is the taxonomic path and the rest of the columns are the frequency in which it appeared in a given sample.
3. **Interpreting Terradactyl's Remote Sensing Data**: The `terradactyl` directory contains the user uploaded csv with the extra headers removed, and the terradactyl csv file that's used for our site reports. The terradactyl csv contains remote sensing data from Google Earth and GBIF related to the user's samples.

## Support
For any queries or technical assistance, please contact our support team at [help@ednaexplorer.org](mailto:help@ednaexplorer.org).
