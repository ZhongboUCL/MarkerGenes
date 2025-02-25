#---Load Libraries------------------------------------------------------------------------------------------------------------------------####
library(tidyverse)
library(EWCE)
library(limma)
library(data.table)

# 2019/01/07 - Files used in this script can be downloaded from https://portal.brain-map.org/atlases-and-data/rnaseq/human-mtg-smart-seq
# Part of their October 2018 MTG-only release

#---Preparing file for SI calculation-----------------------------------------------------------------------------------------------------####

# # This section of code was run separately from the next section "EWCE: Calculating specificity matrices", which was sourced.
# # This is why this section is commented out.
#
# # EWCE requires:
# # 1. Matrix with data, with rows as genes and columns as cells.
# # 2. Annotation dataframe with a minimum of cell_id, level1class and level2class.
#
# #---Preparing sample columns file------
# # sample_columns <- read_csv(file = "/home/rreynolds/data/scRNAseq_AIBS/MTG/human_MTG_2018-06-14_samples-columns.csv")
#
#
# # # Currently 4 classes: Glutamatergic, GABAergic, non-neuronal, no class
# # # Remove no class from metadata.
# # # Split non-neuronal into common cell types e.g. oligos, astrocytes, etc.
# # sample_columns <- sample_columns %>%
# #   unite(level1, c("class", "cluster"), sep = ":", remove = FALSE) %>%
# #   mutate(level1 = str_replace(level1, "Glutamatergic:.*", "Glutamatergic"),
# #          level1 = str_replace(level1, "GABAergic:.*", "GABAergic"),
# #          level1 = str_replace(level1, "Non-neuronal:Oligo.*", "Oligodendrocyte"),
# #          level1 = str_replace(level1, "Non-neuronal:OPC.*", "OPC"),
# #          level1 = str_replace(level1, "Non-neuronal:Astro.*", "Astrocyte"),
# #          level1 = str_replace(level1, "Non-neuronal:Micro.*", "Microglia"),
# #          level1 = str_replace(level1, "Non-neuronal:Endo.*", "Endothelial cell"))
# # write_csv(sample_columns, path = "/home/rreynolds/data/scRNAseq_AIBS/MTG/human_MTG_2018-06-14_samples-columns_level1added.csv")
#
# gene_rows <- read_delim(file = "/home/rreynolds/data/scRNAseq_AIBS/MTG/human_MTG_2018-06-14_genes-rows.txt", delim = ",")
# sample_columns <- read_csv(file = "/home/rreynolds/data/scRNAseq_AIBS/MTG/human_MTG_2018-06-14_samples-columns_level1added.csv")
#
# #---Preparing expr matrix-----
# # Only use exons, on account of introns likely reflecting levels of pre-mRNA.
# exons <- fread(file = "/home/rreynolds/data/scRNAseq_AIBS/MTG/human_MTG_2018-06-14_exon-matrix.csv")
# # introns <- fread(file = "/home/rreynolds/data/scRNAseq_AIBS/MTG/human_MTG_2018-06-14_intron-matrix.csv")
#
# # Generate annotation dataframe
# metadat <- sample_columns %>%
#   dplyr::filter(!class == "no class") %>%
#   dplyr::select(sample_name, class, level1, cluster) %>%
#   mutate(cell_id = sample_name,
#          level1class = level1,
#          level2class = str_replace_all(cluster, " ", "_")) %>%
#   dplyr::select(-sample_name, -level1, -cluster)
#
# # Remove cells from data table with no class, convert gene identifiers from entrez to gene id, and convert to matrix.
# noclass <- sample_columns %>% dplyr::filter(class == "no class") %>% .[["sample_name"]] # amounts to 325 cells
# exons <- exons %>%
#   inner_join(gene_rows %>%
#                dplyr::select(gene, entrez_id),
#              by = c("V1" = "entrez_id")) %>%
#   dplyr::select(gene, everything(), -V1)
#
# matrix.please<-function(dataframe) {
#   # create matrix
#   m<-as.matrix(dataframe[,-1])
#
#   # add row names using first column of dataframe
#   rownames(m)<-dataframe[,1]
#
#   return(m)
# }
#
# exp <- exons %>%
#   dplyr::select(-one_of(noclass)) %>%
#   matrix.please()
#
# # Create list with metadat and matrix.
# # To use with EWCE, must ensure matrix is named 'exp' and metadat is 'annot'.
# AIBS2018 <- list(exp, metadat)
# names(AIBS2018) <- c("exp", "annot")
#
# save(AIBS2018,file="/home/rreynolds/data/scRNAseq_AIBS/MTG/AIBS2018_DataForEWCE.Rda")

#---EWCE: Calculating specificity matrices-----------------------------------------------------------------------------------------------####
# Sourced using:
# nohup Rscript /home/rreynolds/projects/MarkerGenes/data-raw/AIBS2018_GeneratingSImatrix.R &>/home/rreynolds/projects/MarkerGenes/nohup_logs/EWCE_AIBS2018.log&
# Drop genes which do not show significant evidence of varying between level 2 celltypes (based on ANOVA)
Sys.time()
load("/home/rreynolds/data/scRNAseq_AIBS/MTG/AIBS2018_DataForEWCE.Rda")
print("Data loaded.")

exp_DROPPED = drop.uninformative.genes(exp=AIBS2018$exp,level2annot = AIBS2018$annot$level2class)
print("Uninformative genes now removed.")

annotLevels = list(level1class=AIBS2018$annot$level1class,level2class=AIBS2018$annot$level2class)
print("Annotation levels assigned.")

# Remove unneccessary files
rm(AIBS2018)
print("AIBS2018 file now removed.")

# Calculate cell type averages and specificity for each gene
fNames_AIBS2018 = generate.celltype.data(exp=exp_DROPPED,annotLevels=annotLevels,groupName="AIBS2018")
print("Cell type averages and specificity calculated.")
