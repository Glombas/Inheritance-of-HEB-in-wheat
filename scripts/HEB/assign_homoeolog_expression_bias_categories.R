# Aim is to classify triads as balanced, dominant or suppressed like Ricardo did

# Philippa Borrill
# 14-03-2019

# Used https://github.com/Uauy-Lab/WheatHomoeologExpression/blob/master/02.%20Calculate%20triad%20category.ipynb#Definition-of-homoeolog-expression-bias-categories as a model

library("tidyverse")
library("fields")

# set working dir
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))

# load tpms
tpms <- read.table(file="F6_lines_tpm.tsv",sep = "\t", header=T)
head(tpms)
dim(tpms)

# load homoeologs
homologies <- read.csv(file="homoeologs_1_1_1_synt_and_non_synt.csv")
head(homologies)

# now only keep HC genes
HC_expr <- tpms[!grepl("LC",row.names(tpms)),]
head(HC_expr)
dim(HC_expr)

hc_genes_to_use <- data.frame(gene=rownames(HC_expr))
head(hc_genes_to_use)
nrow(hc_genes_to_use)


# which triads have at least 1 homoeolog expressed >0.5 tpm?
head(homologies)

# make into long format and add column whether each gene is "hc_genes_to_use"
long_homoeologs <- homologies %>%
  tidyr::gather(homoeolog, gene, A:D) %>%
  dplyr::mutate("gene_to_use" = gene %in% hc_genes_to_use$gene ) 
head(long_homoeologs)
dim(long_homoeologs)
nrow(long_homoeologs[long_homoeologs$gene_to_use == "TRUE",])

# does each triad have an expressed gene?
group_expr <- long_homoeologs %>%
  dplyr::group_by(group_id) %>%
  dplyr::summarise (n_true = sum(gene_to_use == "TRUE"),
             n_false = sum(gene_to_use == "FALSE"))
head(group_expr)

# select only groups which have at least 1 homoeolog expressed

expressed_groups <- group_expr[group_expr$n_true >0 ,]
head(expressed_groups)
dim(expressed_groups)

# now I want to combine the expression data with this list of expressed groups
head(expressed_groups)

head(long_homoeologs)
dim(long_homoeologs)

long_homoeologs_to_use <- long_homoeologs[long_homoeologs$group_id %in% expressed_groups$group_id,]
head(long_homoeologs_to_use)
dim(long_homoeologs_to_use)

# do a test to make a matrix for tpm expression for one sample:
head(tpms)

tpm_long_homoeologs_to_use <- merge(long_homoeologs_to_use, tpms, by.x="gene", by.y=0) # add the tpm values for the long_homoeologs_to_use
head(tpm_long_homoeologs_to_use)
dim(tpm_long_homoeologs_to_use)

# now select just 1 sample and calculate the relative expression of A, B, D for each triad:
test_sample <- tpm_long_homoeologs_to_use %>%
  dplyr::select(group_id, homoeolog, PW.7.1) %>%
  tidyr::spread(homoeolog,  PW.7.1)
head(test_sample)

# now calculate relative ABD
test_sample$total <- test_sample$A + test_sample$B + test_sample$D
head(test_sample)

test_sample$A_rel <- test_sample$A/test_sample$total
test_sample$B_rel <- test_sample$B/test_sample$total
test_sample$D_rel <- test_sample$D/test_sample$total

head(test_sample)
# only keep triads with a sum >0.5 tpm
test_sample <- test_sample[test_sample$total >0.5,]
dim(test_sample)
head(test_sample)


## how did Ricardo actually assign the homoeologs to bias categories?

### NB to get this to work I will need to make a "test_mat" for each sample then I can just loop through!

# make the "ideal" categories
centers<-t(matrix(c(0.33,0.33,0.33,1,0,0,0,1,0,0,0,1,0,0.5,0.5,0.5,0,0.5,0.5,0.5,0), nrow=3))
colnames(centers)<-c("A","B","D")
rownames(centers)<-c("Central","A.dominant","B.dominant","D.dominant","A.suppressed","B.suppressed","D.suppressed")
head(centers)

test_mat <- as.matrix(test_sample[,c("A_rel","B_rel","D_rel")])
head(test_mat)
is.matrix(test_mat)
rownames(test_mat)<- test_sample$group_id
colnames(test_mat) <- c("A","B","D")
head(test_mat)

expectation_distance <- rdist(test_mat,centers) # this calculate the euclidian distance for each triad to each category
head(expectation_distance)

colnames(expectation_distance)<-c("Central",
                                  "A.dominant",  "B.dominant",  "D.dominant",
                                  "A.suppressed","B.suppressed","D.suppressed")

head(expectation_distance)
rownames(expectation_distance)<-rownames(test_mat) # add back in the triad names
head(expectation_distance)
mins<-apply(expectation_distance, 1, which.min) # select which category each triad falls into
head(mins)
clust_desc<-colnames(expectation_distance) 
head(clust_desc)
name_mins<-clust_desc[mins]
head(name_mins) # give the categories names

general_desc<-c("Central","Dominant",  "Dominant",  "Dominant",
                "Suppressed","Suppressed","Suppressed")

general_name_mins<-general_desc[mins] # add the general category names too

head(general_name_mins)

output_df <- cbind(test_mat,name_mins,general_name_mins) # add together this information about dominance for each triad
head(output_df)


### now do this for each sample:
head(tpm_long_homoeologs_to_use)

list_of_samples <- c(colnames(tpm_long_homoeologs_to_use[,10:ncol(tpm_long_homoeologs_to_use)]))
list_of_samples

# make output dataframe:
head(output_df)
output_df_all_samples <- data.frame(A= numeric(), B= numeric(), D= numeric(), name_mins=character(), general_name_mins=character(),
                                    group_id = numeric(), sample=character())     
output_df_all_samples

for(sample in list_of_samples) {
  print(sample)
  # now select just 1 sample and calculate the relative expression of A, B, D for each triad:
  test_sample <-
    tpm_long_homoeologs_to_use %>%
    dplyr::select(group_id, homoeolog, sample) %>%
    tidyr::spread(homoeolog,  sample)
  head(test_sample)
  
  # now calculate relative ABD
  test_sample$total <- test_sample$A + test_sample$B + test_sample$D
  head(test_sample)
  
  test_sample$A_rel <- test_sample$A/test_sample$total
  test_sample$B_rel <- test_sample$B/test_sample$total
  test_sample$D_rel <- test_sample$D/test_sample$total
  
  head(test_sample)
  dim(test_sample)
  # only keep triads with a sum >0.5 tpm
  test_sample <- test_sample[test_sample$total >0.5,] 
  
  
  ## how did Ricardo actually assign the homoeologs to bias categories?
  
  ### NB to get this to work I will need to make a "test_mat" for each sample then I can just loop through!
  
  # make the "ideal" categories
  centers<-t(matrix(c(0.33,0.33,0.33,1,0,0,0,1,0,0,0,1,0,0.5,0.5,0.5,0,0.5,0.5,0.5,0), nrow=3))
  colnames(centers)<-c("A","B","D")
  rownames(centers)<-c("Central","A.dominant","B.dominant","D.dominant","A.suppressed","B.suppressed","D.suppressed")
  #head(centers)
  
  test_mat <- as.matrix(test_sample[,c("A_rel","B_rel","D_rel")])
  #head(test_mat)
  rownames(test_mat)<- test_sample$group_id
  colnames(test_mat) <- c("A","B","D")
  #head(test_mat)
  
  expectation_distance <- rdist(test_mat,centers) # this calculate the euclidian distance for each triad to each category
  head(expectation_distance)
  
  colnames(expectation_distance)<-c("Central",
                                    "A.dominant",  "B.dominant",  "D.dominant",
                                    "A.suppressed","B.suppressed","D.suppressed")
  
  head(expectation_distance)
  rownames(expectation_distance)<-rownames(test_mat) # add back in the triad names
  head(expectation_distance)
  mins<-apply( expectation_distance, 1, which.min) # select which category each triad falls into
  #head(mins)
  clust_desc<-colnames(expectation_distance) 
  #head(clust_desc)
  name_mins<-clust_desc[mins]
  #head(name_mins) # give the categories names
  
  general_desc<-c("Central","Dominant",  "Dominant",  "Dominant",
                  "Suppressed","Suppressed","Suppressed")
  
  general_name_mins<-general_desc[mins] # add the general category names too
  
  #head(general_name_mins)
  
  output_mat <- cbind(test_mat,name_mins,general_name_mins)# add together this information about dominance for each triad
  output_df <- as.data.frame(output_mat)
  head(output_df)
  output_df$group_id <- rownames(output_df) # make group_id into a column
  output_df$sample <- sample # add which sample this is as a column
  
  head(output_df)
  
  output_df_all_samples <- rbind(output_df_all_samples, output_df) # puts all samples into a big table
  
}

head(output_df_all_samples)
dim(output_df_all_samples)

write.csv(file="bias_category_all_samples.csv", output_df_all_samples, row.names = F)


### now do this for each sample AND keep original values:
head(tpm_long_homoeologs_to_use)

list_of_samples <- c(colnames(tpm_long_homoeologs_to_use[,10:ncol(tpm_long_homoeologs_to_use)]))
list_of_samples

# make output dataframe:
head(output_df)
output_df_all_samples <- data.frame(A_tpm= numeric(), B_tpm= numeric(), D_tpm= numeric(), A= numeric(), B= numeric(), D= numeric(), name_mins=character(), general_name_mins=character(),
                                    group_id = numeric(), sample=character())     
output_df_all_samples

for(sample in list_of_samples) {
  print(sample)
  # now select just 1 sample and calculate the relative expression of A, B, D for each triad:
  test_sample <-
    tpm_long_homoeologs_to_use %>%
    dplyr::select(group_id, homoeolog, sample) %>%
    tidyr::spread(homoeolog,  sample)
  head(test_sample)
  
  # now calculate relative ABD
  test_sample$total <- test_sample$A + test_sample$B + test_sample$D
  head(test_sample)
  
  test_sample$A_rel <- test_sample$A/test_sample$total
  test_sample$B_rel <- test_sample$B/test_sample$total
  test_sample$D_rel <- test_sample$D/test_sample$total
  
  head(test_sample)
  dim(test_sample)
  # only keep triads with a sum >0.5 tpm
  test_sample <- test_sample[test_sample$total >0.5,] 
  
  
  ## how did Ricardo actually assign the homoeologs to bias categories?
  
  ### NB to get this to work I will need to make a "test_mat" for each sample then I can just loop through!
  
  # make the "ideal" categories
  centers<-t(matrix(c(0.33,0.33,0.33,1,0,0,0,1,0,0,0,1,0,0.5,0.5,0.5,0,0.5,0.5,0.5,0), nrow=3))
  colnames(centers)<-c("A","B","D")
  rownames(centers)<-c("Central","A.dominant","B.dominant","D.dominant","A.suppressed","B.suppressed","D.suppressed")
  #head(centers)
  
  test_mat <- as.matrix(test_sample[,c("A_rel","B_rel","D_rel")])
  #head(test_mat)
  rownames(test_mat)<- test_sample$group_id
  colnames(test_mat) <- c("A","B","D")
  #head(test_mat)
  
  expectation_distance <- rdist(test_mat,centers) # this calculate the euclidian distance for each triad to each category
  head(expectation_distance)
  
  colnames(expectation_distance)<-c("Central",
                                    "A.dominant",  "B.dominant",  "D.dominant",
                                    "A.suppressed","B.suppressed","D.suppressed")
  
  head(expectation_distance)
  rownames(expectation_distance)<-rownames(test_mat) # add back in the triad names
  head(expectation_distance)
  mins<-apply( expectation_distance, 1, which.min) # select which category each triad falls into
  #head(mins)
  clust_desc<-colnames(expectation_distance) 
  #head(clust_desc)
  name_mins<-clust_desc[mins]
  #head(name_mins) # give the categories names
  
  general_desc<-c("Central","Dominant",  "Dominant",  "Dominant",
                  "Suppressed","Suppressed","Suppressed")
  
  general_name_mins<-general_desc[mins] # add the general category names too
  
  #head(general_name_mins)
  
  output_mat <- cbind("A_tpm" =test_sample$A, "B_tpm" =test_sample$B, "D_tpm"=test_sample$D, test_mat,name_mins,general_name_mins)# add together this information about dominance for each triad
  output_df <- as.data.frame(output_mat)
  head(output_df)
  output_df$group_id <- rownames(output_df) # make group_id into a column
  output_df$sample <- sample # add which sample this is as a column
  
  head(output_df)
  
  output_df_all_samples <- rbind(output_df_all_samples, output_df) # puts all samples into a big table
  
}

head(output_df_all_samples)
dim(output_df_all_samples)

write.csv(file="bias_category_all_samples_inc_orig_expr.csv", output_df_all_samples, row.names = F)

