library("dplyr")
library("data.table")
library("ggplot2")

colocs = readr::read_tsv("merged_colocs.tsv") %>%
  dplyr::filter(qtl_subset != "qtl_subset") %>%
  dplyr::mutate(PP.H4.abf = as.numeric(PP.H4.abf),
                PP.H3.abf = as.numeric(PP.H3.abf)) %>%
  dplyr::mutate(quant = ifelse(qtl_subset %like% "_tx", "transcript", "gene")) %>%
  dplyr::mutate(quant = ifelse(qtl_subset %like% "_txrev", "txrevise", quant)) %>%
  dplyr::mutate(quant = ifelse(qtl_subset %like% "_exon", "exon", quant))


plt = ggplot(colocs, aes(x = PP.H3.abf, y = PP.H4.abf, color = quant)) + 
  geom_point(alpha = 0.8) +
  theme_light() +
  theme(panel.grid = element_blank()) +
  xlab("PP3 (distinct causal variants)") +
  ylab("PP4 (shared causal variant)")
  
ggsave("HMGCR_coloc_plot.pdf", plot = plt, width = 3.5, height = 2.7)

#######################
# ordering the datasets

ontology_map = readr::read_tsv("../../../ontology_mappings/tissue_ontology_mapping.tsv")
friendly_names = readr::read_tsv("../../../ontology_mappings/friendly_names.tsv") %>%
  dplyr::select(ontology_term, ontology_tissue)
# rename blueprint dataset for consistency with effect dataset names
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
# place immune t-cells together
ontology_map = ontology_map %>% dplyr::mutate(dummy = ifelse(qtl_group %like% "anti", "ANTI", ontology_tissue), 
                                              ontology_tissue = ifelse(qtl_group %like% "anti", paste(ontology_tissue, "(anti-CD3-CD28)"), ontology_tissue))
# place quach monocyte and nedelec macrophage together because they load on one factor
ontology_map = ontology_map %>% dplyr::mutate(dummy = ifelse(study_qtlgroup == "Quach_2016.monocyte_naive", "z-monocyte", dummy))
ontology_map = ontology_map %>% dplyr::mutate(dummy = ifelse(study_qtlgroup == "Nedelec_2016.macrophage_naive", "a-macrophage", dummy))
# sort studies
ontology_map = ontology_map %>% dplyr::arrange(tissue_fct, dummy, study)
ontology_map = ontology_map %>% dplyr::mutate(heatmap_label = paste(study, ontology_tissue, sep=" "))

# remove stimulated datasets
datasets = ontology_map$study_qtlgroup
datasets = !(datasets %like% "IFNg" | 
               datasets %like% "Salmonella" | 
               datasets %like% "Listeria" | 
               datasets %like% "IAV" | 
               datasets %like% "Pam3CSK4" | 
               datasets %like% "LPS" | 
               datasets %like% "R848")
ontology_map = ontology_map[datasets,]

colors = c("#e41a1c","#377eb8","#4daf4a","#984ea3","#ff7f00","#a65628","#fed976","#f781bf","#999999")
names(colors) = c("blood","lymphocyte","LCL","neutrophil","monocyte","macrophage","brain","iPSC","other")

#####################

#Make effect size plots
exon_effect_sizes = readr::read_tsv("HMGCR_exon.tsv")
exon_effect_sizes = exon_effect_sizes %>%  dplyr::mutate(qtl_group = stringr::str_remove(file_name, "_exon.nominal.sorted.tsv.gz"))

exon_effect_sizes = dplyr::inner_join(ontology_map[c("heatmap_label", "study_qtlgroup", "tissue_fct")], exon_effect_sizes, by = c("study_qtlgroup"="qtl_group"))
exon_effect_sizes = exon_effect_sizes %>% dplyr::mutate(study_qtlgroup=factor(study_qtlgroup, levels=study_qtlgroup))

# calculate 95% confidence interval
conf.level = 0.95
ci.value <- -qnorm( ( 1 - conf.level ) / 2 )
exon_effect_sizes = dplyr::mutate(exon_effect_sizes, interval = ci.value * se)

plt = ggplot(exon_effect_sizes, aes(x = study_qtlgroup, y = beta, ymin = beta - interval, ymax = beta + interval, colour=tissue_fct)) + 
  geom_point() + 
  scale_color_manual(values=colors, name="Group")+
  geom_hline(yintercept=0, colour="grey") + 
  geom_errorbar(width = 0.1) + 
  xlab("Dataset") + 
  ylab("Effect size") +
  ylim(c(-0.5, 2)) +
  theme_light() +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        plot.margin = margin(1, 1, 1, 3, "cm"),panel.grid = element_blank(),)+
  geom_hline(yintercept = 0)

ggsave("HMGCR_exon_forest.pdf", plot = plt, width = 8, height = 3)

#Make plotly plot
ggplotly_plot <- plotly::ggplotly(plt)
htmlwidgets::saveWidget(widget = plotly::as_widget(ggplotly_plot),
                        file = "HMGCR_exon_forest.html",
                        libdir = "dependencies")


#Make gene expression effect size plots
gene_effect_sizes = readr::read_tsv("HMGCR_gene.tsv")

gene_effect_sizes = gene_effect_sizes %>%  dplyr::mutate(qtl_group = stringr::str_remove(file_name, "_ge.nominal.sorted.tsv.gz"))

gene_effect_sizes = dplyr::inner_join(ontology_map[c("heatmap_label", "study_qtlgroup", "tissue_fct")], gene_effect_sizes, by = c("study_qtlgroup"="qtl_group"))
gene_effect_sizes = gene_effect_sizes %>% dplyr::mutate(study_qtlgroup=factor(study_qtlgroup, levels=study_qtlgroup))



# calculate 95% confidence interval
conf.level = 0.95
ci.value <- -qnorm( ( 1 - conf.level ) / 2 )
gene_effect_sizes = dplyr::mutate(gene_effect_sizes, interval = ci.value * se)

plt = ggplot(gene_effect_sizes, aes(x = study_qtlgroup, y = beta, ymin = beta - interval, ymax = beta + interval,  colour=tissue_fct)) + 
  geom_point() + 
  scale_color_manual(values=colors, name="Group") +
  geom_hline(yintercept=0, colour="grey") + 
  geom_errorbar(width = 0.1) + 
  xlab("Dataset") + 
  ylab("Effect size") +
  coord_cartesian(ylim = c(-0.5, 2)) +
  theme_light() +
  theme(axis.text.x = element_blank(),
        axis.ticks.x = element_blank(),
        plot.margin = margin(1, 1, 1, 3, "cm"),panel.grid = element_blank(),)+
  geom_hline(yintercept = 0) 

ggsave("HMGCR_gene_forest.pdf", plot = plt, width = 8, height = 3)

#Make plotly plot
ggplotly_plot <- plotly::ggplotly(plt)
htmlwidgets::saveWidget(widget = plotly::as_widget(ggplotly_plot),
                        file = "HMGCR_gene_forest.html",
                        libdir = "dependencies")




#Make regional plot
#bcftools view -r 5:74855259-75855259 LDLC.GRCh38.sorted.vcf.gz -Oz -o LDLC_HMGCR.vcf.gz
# tabix GEUVADIS.LCL_exon.nominal.sorted.tsv.gz 5:74855259-75855259 > ~/GEUVADIS_HMGCR_exon.tsv

eqtl_data = readr::read_tsv("HipSci_HMGCR_exon.tsv.gz") %>%
  dplyr::filter(molecular_trait_id == "ENSG00000113161.16_5_75355215_75355364") %>%
  dplyr::mutate(z_score = beta/se) %>%
  dplyr::select(position, z_score) %>%
  dplyr::mutate(type = "HMGCR exon QTL")
gwas_data = gwasvcf::query_gwas("LDLC_HMGCR.vcf.gz", chrompos = "5:74855259-75855259") %>% 
  gwasvcf::vcf_to_granges() %>% 
  as.data.frame() %>%
  dplyr::as_tibble() %>%
  dplyr::transmute(position = start, z_score = ES/SE, type = "LDL cholesterol")
gwas_data_selected = dplyr::semi_join(gwas_data, eqtl_data, by = "position")

joint_data = dplyr::bind_rows(eqtl_data, gwas_data)

#Import exon QTL credible sets
cs_exon = readr::read_tsv("ftp://ftp.ebi.ac.uk/pub/databases/spot/eQTL/credible_sets/HipSci.iPSC_exon.purity_filtered.txt.gz") %>%
  dplyr::filter(phenotype_id == "ENSG00000113161.16_5_75355215_75355364")

#Flag the credible set in GWAS results
gwas_flagged = dplyr::mutate(joint_data, in_cs = ifelse(position %in% cs_exon$pos, TRUE, FALSE)) %>%
  dplyr::mutate(LP = (2*pnorm(-abs(z_score), log.p = T))/log(10)) %>%
  dplyr::mutate(type = factor(type, levels = c("LDL cholesterol","HMGCR exon QTL")))

#Make manhattan plots
manhattan = ggplot(gwas_flagged, aes(y = abs(z_score), x = position, color = in_cs)) + 
  geom_point(size = 1) + 
  facet_grid(type~., scales = "free_y") +
  theme_bw() +
  theme(panel.grid = element_blank()) +
  xlab("Chromosome 2 position") + 
  ylab("abs(z-score)") + 
  scale_colour_manual(name = "group",
                      values=c("black","red")) +
  theme(legend.position = "none")
ggsave("HMGCR_manhattan.pdf", plot = manhattan, width = 4, height = 3)


#Make the same plot for gene expression
eqtl_data = readr::read_tsv("FUSION_muscle_HMGCR_gene.tsv.gz") %>%
  dplyr::filter(molecular_trait_id == "ENSG00000113161") %>%
  dplyr::mutate(z_score = beta/se) %>%
  dplyr::select(position, z_score) %>%
  dplyr::mutate(type = "HMGCR eQTL")
gwas_data = gwasvcf::query_gwas("LDLC_HMGCR.vcf.gz", chrompos = "5:74855259-75855259") %>% 
  gwasvcf::vcf_to_granges() %>% 
  as.data.frame() %>%
  dplyr::as_tibble() %>%
  dplyr::transmute(position = start, z_score = ES/SE, type = "LDL cholesterol")
gwas_data_selected = dplyr::semi_join(gwas_data, eqtl_data, by = "position")

joint_data = dplyr::bind_rows(eqtl_data, gwas_data)

#Import exon QTL credible sets
cs_exon = readr::read_tsv("ftp://ftp.ebi.ac.uk/pub/databases/spot/eQTL/credible_sets/FUSION.muscle_naive_ge.purity_filtered.txt.gz") %>%
  dplyr::filter(phenotype_id == "ENSG00000113161")

#Flag the credible set in GWAS results
gwas_flagged = dplyr::mutate(joint_data, in_cs = ifelse(position %in% cs_exon$pos, TRUE, FALSE)) %>%
  dplyr::mutate(LP = (2*pnorm(-abs(z_score), log.p = T))/log(10)) %>%
  dplyr::mutate(type = factor(type, levels = c("LDL cholesterol","HMGCR eQTL")))

#Make manhattan plots
manhattan = ggplot(gwas_flagged, aes(y = abs(z_score), x = position, color = in_cs)) + 
  geom_point(size = 1) + 
  facet_grid(type~., scales = "free_y") +
  theme_bw() +
  theme(panel.grid = element_blank()) +
  xlab("Chromosome 2 position") + 
  ylab("abs(z-score)") + 
  scale_colour_manual(name = "group",
                      values=c("black","red")) +
  theme(legend.position = "none")
ggsave("HMGCR_manhattan_FUSION.png", plot = manhattan, width = 4, height = 3)


