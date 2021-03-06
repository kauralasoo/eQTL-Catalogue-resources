library("tidyverse")
library("ggplot2")
library("RColorBrewer")
library("ggrepel")
library("data.table")

sharing = readr::read_tsv("mash_sharing.tsv")

ontology_map = readr::read_tsv("../../../ontology_mappings/tissue_ontology_mapping.tsv")
friendly_names = readr::read_tsv("../../../ontology_mappings/friendly_names.tsv") %>%
  dplyr::select(ontology_term, ontology_tissue)
ontology_map$study[c(1,2,3)] = c("BLUEPRINT_SE", "BLUEPRINT_SE", "BLUEPRINT_PE")
ontology_map <- ontology_map %>% dplyr::mutate(study_qtlgroup = paste0(study, ".", qtl_group)) %>%
  dplyr::left_join(friendly_names) %>%
  dplyr::mutate(sample_class = ifelse(ontology_tissue %like% "brain", "brain", "other")) %>%
  dplyr::mutate(sample_class = ifelse(ontology_tissue %like% "LCL", "LCL", sample_class)) %>%
  dplyr::mutate(sample_class = ifelse(ontology_tissue %like% "monocyte", "monocyte", sample_class)) %>%
  dplyr::mutate(sample_class = ifelse(ontology_tissue %like% "macrophage", "macrophage", sample_class)) %>%
  dplyr::mutate(sample_class = ifelse(ontology_tissue %like% "blood", "blood", sample_class)) %>%
  dplyr::mutate(sample_class = ifelse(ontology_tissue %like% "neutrophil", "neutrophil", sample_class)) %>%
  dplyr::mutate(sample_class = ifelse(ontology_term %in% c("CL_0000236","CL_0002677","CL_0002678","CL_0000624","CL_0000625","CL_0000623","CL_0000899","CL_0000546","CL_0000545","CL_0000899","CL_0002038","CL_0000084"), "lymphocyte", sample_class)) %>%
  dplyr::mutate(sample_class = ifelse(ontology_tissue %like% "iPSC", "iPSC", sample_class))

fct_levels = c("blood","lymphocyte","LCL","neutrophil","monocyte","macrophage","brain","iPSC","other")
ontology_map = dplyr::mutate(ontology_map, tissue_fct = factor(sample_class, levels = fct_levels))

# friendly label
ontology_map = ontology_map %>% dplyr::mutate(label = paste(study, ontology_tissue, sep=" "))

# lead datasets
leads=c("BLUEPRINT_SE.neutrophil", "BLUEPRINT_SE.monocyte", "BLUEPRINT_PE.T-cell","Schmiedel_2018.CD4_T-cell_naive","Schmiedel_2018.B-cell_naive", "Alasoo_2018.macrophage_naive", "GEUVADIS.LCL", 
        "TwinsUK.blood", "GENCORD.fibroblast", "HipSci.iPSC", "ROSMAP.brain_naive", "TwinsUK.fat", "TwinsUK.skin", "FUSION.muscle_naive")

#Convert sharing matrix into a data frame
df_sharing = pivot_longer(sharing, cols=c(-dataset), names_to="dataset2")
# remove diagonal values
df_sharing = df_sharing %>% filter(value < 1)

# filter similarities for lead datasets
df_sharing = filter(df_sharing, dataset %in% leads)
df_sharing = df_sharing %>% left_join(ontology_map[c("tissue_fct", "study_qtlgroup")], by=c("dataset2"="study_qtlgroup"))
# add friendly label to lead datasets
df_sharing = df_sharing %>% left_join(ontology_map[c("label", "study_qtlgroup")], by=c("dataset"="study_qtlgroup"))
df_sharing = dplyr::rename(df_sharing, sharing = value) %>%
  dplyr::mutate(dataset = factor(dataset, levels = leads)) %>%
  dplyr::arrange(dataset) %>%
  dplyr::mutate(label = factor(label, levels = unique(label)))


plt <- ggplot(df_sharing, aes(x = label, y = sharing, colour=tissue_fct, label = dataset2)) +
    geom_jitter(width = 0.2) +
    xlab("") +
    ylab("Pairwise eQTL sharing") +
    scale_colour_manual(name = "group",
                        values=c("#e41a1c","#377eb8","#4daf4a","#984ea3","#ff7f00","#a65628","#fed976","#f781bf","#999999"))  +
    theme_light() + 
    theme(panel.grid = element_blank()) + 
    theme(axis.text.x = element_text(angle = 330, vjust = 1, hjust=0)) +
    scale_x_discrete() 
plt


ggsave("sharing_distribution.pdf", plt, width = 10, height = 4)

#Make plotly plot
ggplotly_plot <- plotly::ggplotly(plt)
htmlwidgets::saveWidget(widget = plotly::as_widget(ggplotly_plot),
                        file = "sharing_distribution.html",
                        libdir = "dependencies")


#Estimate sharing between bulk tissues
a = dplyr::filter(df_sharing, tissue_fct == "other")
other_sharing = dplyr::filter(a, dataset %in% a$dataset2) %>%
  dplyr::filter(!(dataset %like% "fibroblast")) %>%
  dplyr::filter(!(dataset2 %like% "fibroblast"))

#Estimate sharing between LCLs
a = dplyr::filter(df_sharing, tissue_fct == "LCL")
lcl_sharing = dplyr::filter(a, dataset %in% a$dataset2) %>%
  dplyr::filter(!(dataset %like% "fibroblast")) %>%
  dplyr::filter(!(dataset2 %like% "fibroblast"))


