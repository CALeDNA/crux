# Manage packages -----

#1. Download packages from CRAN
.cran_packages  <-  c("ggplot2", "plyr", "dplyr", "reshape2", "tibble", "devtools", "Matrix", "mgcv", "readr", "stringr")
.inst <- .cran_packages %in% installed.packages()
if (any(!.inst)) {
  install.packages(.cran_packages[!.inst], repos = "http://cran.rstudio.com/")
}

devtools::install_github("helixcn/seqRFLP")

# 2. Download packages from biocLite
BiocManager::install(c("phyloseq", "genefilter", "impute", "Biostrings"))

# .dada_version = "1.6.0"
# .dada_version_gh = "v1.6"
# if("dada2" %in% installed.packages()){
#   if(packageVersion("dada2") == .dada_version) {
#     cat("congrats, right version of dada2")
#   } else {
#     devtools::install_github("benjjneb/dada2", ref=.dada_version_gh)
#   }
# }

# if(!("dada2" %in% installed.packages())){
#   # if the user doesn't have dada2 installed, install version 1.6 from github
#   devtools::install_github("benjjneb/dada2", ref=.dada_version_gh)
# }

# library("dada2")
# cat(paste("dada2 package version:", packageVersion("dada2")))
# if(packageVersion("dada2") != '1.6.0') {
#   stop("Please make sure you have dada version ", .dada_version, " installed")
# }