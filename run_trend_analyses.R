# Trend analyses ----------------

# load libraries -------
library(tidyverse)
library(magrittr)
library(AER)
library(MASS)
library(COMPoissonReg)
library(performance)
library(car)

#library(AICcmodavg)


# AMR data analysis ---------------------
# load dMASS# load data ------------

AMR_comparative_interactive <- read_csv("Data/combined_data_for_analysis.csv") %>%
  mutate(category = paste(Pathogen,Antimicrobial, Region,Host, sep = "_"))

#
# Run models ----

combined_categories <- unique(AMR_comparative_interactive$category)

# TESTING: uncomment to restrict the loop to a category subset
# combined_categories2 <- combined_categories[22:30]

# Diagnostic preview: prints range-to-mean ratio per category before running models.
# The same ratio is recalculated inline during icon assignment in the model loop.
var_list = list()

for(i in combined_categories){
  print(i)
  dataset_analysis<- AMR_comparative_interactive %>%
    filter(category == i)
  degree_var= (max(dataset_analysis$Percent_resistant, na.rm = TRUE)-min(dataset_analysis$Percent_resistant, na.rm = TRUE))/mean(as.numeric(dataset_analysis$Percent_resistant), na.rm = TRUE)
  var_list[[i]] <-degree_var
  print(degree_var)
}

#make list for overdispersion plots
overdispersion_plot_list<- list()


#make csv for graph data with header

start_data_frame <- tibble(
  "Year" = "",
  "Year_recent" = "",
  "Pathogen" = "",
  "Antimicrobial"= "",
  "Percent_resistant"= "",
  "Region" = "",
  "Percent_resistant_predict"= "",
  "Surveillance" = "",
  "Host"="",
  "CI_upper"= "",
  "CI_lower"= "",
  "Sample_size.x" = "",
  "icon" = "",
  "p.value" = "",
  "signif_level_raw" = "",
  "recent_years" = ""
)



# RUN-ONCE: uncomment to initialise the output CSV with a header row before running the loop
# write_csv(start_data_frame, file = "AMR_data_and_GLM_predictions_revised_method.csv")

#also make output folders: AMR_GLM_predictions, AMR_GLM_output_summaries

# To run a single category for testing, set: combined_categories2 <- "N. gonorrhea_Azithromycin_Belgium_NRC_samples"
## Model loop ----
for(i in combined_categories){
  
  ## Subset data ----
  
  dataset_analysis_raw<- AMR_comparative_interactive %>%
    filter(category == i) %>%
    mutate(Year = as.numeric(Year),
           Number_resistants = as.integer(Sample_size*Percent_resistant/100))
  min_year = min(dataset_analysis_raw$Year)
  max_year = max(dataset_analysis_raw$Year)
  data_length = max_year-min_year
  dataset_analysis <- dataset_analysis_raw %>%  
    mutate(Year_simple = Year - min_year)
  
  if(data_length > 9) {
    dataset_analysis <- dataset_analysis %>%
      mutate(Year_recent = if_else(Year>2019,"Y","N")
      )
  }else{
    dataset_analysis <- dataset_analysis %>%
      mutate(Year_recent = NA)
  }
  
  
  
  
  
  #make a file name to print each analysis
  
  output_file_name <- paste("AMR_GLM_output_summaries/GLM_output_",i,"revised_method.txt",sep="") 
  
  #print title of analysis
  capture.output(print(paste("GLM analysis of ",i,sep="")),file = output_file_name)
  
  if(max_year-min_year < 4){
    capture.output(print("Too few data points for model"),file = output_file_name)
    graph_data <- dataset_analysis %>%
      mutate(Percent_resistant_predict = "",
             CI_upper = "",
             CI_lower = "",
             Sample_size.x = "Sample_size",
             icon = "",
             signif_level = "",
             p.value = "",
             signif_level_raw = "",
             recent_years = "") %>%
      dplyr::select(Year,Pathogen, Antimicrobial,Percent_resistant,Region, Percent_resistant_predict,Surveillance,Host,CI_upper,CI_lower,Sample_size.x,
                    icon, signif_level)
  } else if(sum(as.numeric(dataset_analysis$Percent_resistant), na.rm = T) == 0){
    capture.output(print("No resistance- can't fit model"),file = output_file_name)
    graph_data <- dataset_analysis %>%
      mutate(Percent_resistant_predict = "",
             CI_upper = "",
             CI_lower = "",
             Sample_size.x = "Sample_size",
             icon = "",
             signif_level = "",
             p.value= "",
             signif_level_raw= "",
             recent_years = "") %>%
      dplyr::select(Year,Year_recent, Pathogen, Antimicrobial,Percent_resistant,Region, Percent_resistant_predict,Surveillance,Host,CI_upper,CI_lower,Sample_size.x,
                    icon, p.value,signif_level_raw, recent_years)
  } else {
    
    ##  Fit models ----
    
    if(is.na(dataset_analysis$Year_recent[1])){   # if not considering year recent as data set length too short
      
      ## Fit Poisson ----
      
      glmpoissonirr <- glm(Number_resistants~Year_simple + offset(log(Sample_size)), data = dataset_analysis, family = poisson(link = "log"))
      
      
      ##  Fit negative binomial ----
      
      nb <- glm.nb(Number_resistants~Year_simple + offset(log(Sample_size )), data = dataset_analysis )
      
      
      
    } else {  # dataset spans >9 years: test for a post-2019 slope change
      
      
      glmpoissonirr0 <- glm(Number_resistants~Year_simple + offset(log(Sample_size)), data = dataset_analysis, family = poisson(link = "log"))
      
      
      ##  Fit negative binomial ----
      
      nb0 <- glm.nb(Number_resistants~Year_simple + offset(log(Sample_size )), data = dataset_analysis )
      
      
       glmpoissonirr1 <- glm(Number_resistants~Year_simple*Year_recent + offset(log(Sample_size)), data = dataset_analysis, family = poisson(link = "log"))
      
      capture.output(print("Check if last 5 years significant in poisson"),file = output_file_name)
      capture.output(print(summary(glmpoissonirr1)),file = output_file_name)
      pois_vs_pois1 <- lrtest(glmpoissonirr0, glmpoissonirr1)
      
      # LRT p < 0.05: Year_recent interaction improves fit — use the richer model
      if (pois_vs_pois1$`Pr(>Chisq)`[2] < 0.05) {
        glmpoissonirr <- glmpoissonirr1
      } else {
        glmpoissonirr <- glmpoissonirr0
      }
      
      
      ## Fit negative binomial ----
      
      nb1 <- glm.nb(Number_resistants~Year_simple*Year_recent + offset(log(Sample_size )), data = dataset_analysis )
      
      capture.output(print("Check if last 5 years significant in nb"),file = output_file_name)
      capture.output(print(summary(nb1)),file = output_file_name)
      nb1_vs_nb2 <- lrtest(nb0, nb1)
      
      # LRT p < 0.05: Year_recent interaction improves fit — use the richer model
      if (nb1_vs_nb2$`Pr(>Chisq)`[2] < 0.05) {
        nb <- nb1
      } else {
        nb <- nb0
      }
      
    } 
    
    
    
    # calculate dispersion parameter
    dp = sum(residuals(glmpoissonirr,type ="pearson")^2)/glmpoissonirr$df.residual
    
    #print over vs underdispersion
    
    
    underdispersed<- dispersiontest(glmpoissonirr,alternative = c("less") )
    
    
    ##  Select model and generate predictions ----
    #MAKE COMPARISONS
    
    #dispersion
    
    overdispersed<- dispersiontest(glmpoissonirr,alternative = c("greater") )
    
    #anova
    pois_vs_NB<- lrtest(glmpoissonirr,nb)
    
    #aic
    # Poisson AIC    
    ##extract log-likelihood
    LL <- logLik(glmpoissonirr)[1]
    ##extract number of parameters
    K.mod <- coef(glmpoissonirr) + 1
    # ##compute AICc with full likelihood
    # AICcCustom(LL, K.mod, nobs = nrow(dataset_analysis))
    # 
    # AIC_poisson<- AICcCustom(LL, K.mod, nobs = nrow(dataset_analysis))   
    # AIC_poisson_value<- AICcCustom(LL, K.mod, nobs = nrow(dataset_analysis))[1]
    # 
    # # NB model AIC 
    # AIC_NB <- AIC(nb)
    # 
    
    # LRT p < 0.05: NB fits significantly better than Poisson — likely overdispersed data.
    # Warning printed when model choice and dispersion test disagree (flag for manual inspection).
    if (pois_vs_NB$`Pr(>Chisq)`[2] < 0.05) {
      selected_model <- nb
      if(overdispersed$p.value > 0.05){
        print(paste("CHECK OUTPUTS - NB selected but no overdispersal for ", i ))
      }
    } else if (pois_vs_NB$`Pr(>Chisq)`[2] > 0.05) {
      selected_model <- glmpoissonirr
      if(overdispersed$p.value < 0.05){
        print(paste("CHECK OUTPUTS - poisson selected but poss overdispersal for ",i))
      }
    } else {
      print(paste("ERROR no model selected for",i))
    }
    
    #make predicted dataset - save it 
    length_years = max_year - min_year
    
    ndata<- tibble(
      Year = seq(min_year,max_year,by =1),
      Year_simple = seq(0,length_years,by = 1),
      Sample_size = rep(200,length_years+1),
      category = rep(i,length_years+1)
    )
    
    if(data_length > 9) {
      ndata <- ndata %>%
        mutate(Year_recent = if_else(Year>2019,"Y","N")
        )
    }else{
      ndata <- ndata %>%
        mutate(Year_recent = NA)
      
      
    }
    ndata <- add_column(ndata, fit = predict(selected_model, newdata = ndata, type = 'response'))
    
    #make confidence intervals - based on link function
    #find inverse of link function:
    ilink<-family(selected_model)$linkinv
    
    ndata <- bind_cols(ndata, setNames(as_tibble(predict(selected_model, ndata, se.fit = TRUE)[1:2]),
                                       c('fit_link','se_link')))
    
    ndata <- mutate(ndata,
                    fit_resp  = ilink(fit_link),
                    right_upr = ilink(fit_link + (2 * se_link)),
                    right_lwr = ilink(fit_link - (2 * se_link)))
    
    
    # extract pvalue of model
    selected_model_p_value <- coef(summary(selected_model))[,'Pr(>|z|)'][2]
    
    #if signif - extract direction of model
    if(selected_model_p_value<0.05){
      if(coef(summary(selected_model))[,'Estimate'][2] > 0){
        model_icon <- "upward_arrow"
        signif = case_when(
          selected_model_p_value > 0.01 && selected_model_p_value < 0.05 ~ "*",
          selected_model_p_value > 0.001 && selected_model_p_value < 0.01 ~ "**",
          selected_model_p_value < 0.001 ~ "***"
        )
      }else if(coef(summary(selected_model))[,'Estimate'][2] < 0){
        model_icon = "downward_arrow"
        signif = case_when(
          selected_model_p_value > 0.01 && selected_model_p_value < 0.05 ~ "*",
          selected_model_p_value > 0.001 && selected_model_p_value < 0.01 ~ "**",
          selected_model_p_value < 0.001 ~ "***"
        )
      }
    } else if(selected_model_p_value>0.05){
      # Non-significant trend: use range/mean ratio to distinguish oscillating from stable.
      # Threshold of 0.25 (25% of mean) chosen as a meaningful biological variation cutoff.
      if((max(dataset_analysis$Percent_resistant)-min(dataset_analysis$Percent_resistant))/mean(dataset_analysis$Percent_resistant) > 0.25){
        model_icon <- "oscilate"
        signif = ""
      }else if((max(dataset_analysis$Percent_resistant)-min(dataset_analysis$Percent_resistant))/mean(dataset_analysis$Percent_resistant) < 0.25){
        model_icon <- "equals"
        signif <- ""
      }
    }
    
    
    
    
    # Detect direction of the post-2019 slope from the selected model's coefficient table.
    # 2 rows = intercept + Year_simple only (no Year_recent term — short dataset).
    # 3 rows = + Year_recent main effect; 4 rows = + Year_simple:Year_recent interaction.
    # The last coefficient in each case carries the recent-period direction.
    if(dim(coef(summary(selected_model)))[1] == 2){
      year_recent = "Non"
    }else if(dim(coef(summary(selected_model)))[1] == 3){
      if(coef(summary(selected_model))[,'Estimate'][3]>0){
        year_recent = "Up"}
      else if(coef(summary(selected_model))[,'Estimate'][3]<0){
        year_recent = "Down"
      }
    }else if(dim(coef(summary(selected_model)))[1] == 4){
      if(coef(summary(selected_model))[,'Estimate'][4]>0){
        year_recent = "Up"}
      else if(coef(summary(selected_model))[,'Estimate'][4]<0){
        year_recent = "Down"
      }
    } else{
      print("Error with year recent")
    }
    
    
    
    
    
    predict_data <- ndata %>%
      mutate(Percent_resistant_predict = fit/Sample_size*100,
             CI_upper = right_upr/Sample_size*100,
             CI_lower = right_lwr/Sample_size*100,
             icon = model_icon,
             p.value = selected_model_p_value,
             signif_level_raw = signif,
             recent_years = year_recent)
    
    graph_data <- left_join(dataset_analysis,predict_data, by = c("Year","Year_simple","Year_recent")) %>%
      dplyr::select(Year,Year_recent, Pathogen, Antimicrobial,Percent_resistant,Region, Percent_resistant_predict,Surveillance,Host,CI_upper,CI_lower,Sample_size.x,
                    icon, p.value,signif_level_raw, recent_years)
    
    
    
    
    #save dataset
    
    predicted_dataset_filename <- paste("AMR_GLM_predictions/GLM_predictions",i,"revised_method.csv",sep="") 
    
    write_csv(predict_data,file = predicted_dataset_filename)  
    write_csv(graph_data,file = "AMR_data_and_GLM_predictions_revised_method.csv", append = TRUE)
    
    #print selected model to GLM output
    capture.output(print("SELECTED MODEL----------------------------"),file = output_file_name, append = "TRUE")
    capture.output(print(selected_model),file = output_file_name, append = "TRUE")
    capture.output(print(summary(selected_model)),file = output_file_name, append = "TRUE")
    
    
    ##  Save outputs to log ----
    
    
    #print poisson p value to 
    
    capture.output(print("TEST FOR DISPERSION-------------------- "),file = output_file_name, append = "TRUE") 
    capture.output(print(paste("dispersal parameter= ",dp,"If >1 then overdispersed")),file = output_file_name, append = "TRUE")
    
    capture.output(print(overdispersed),file = output_file_name, append = "TRUE")
    
    capture.output(print(underdispersed),file = output_file_name, append = "TRUE")
    capture.output(print("ANOVA COMPARING MODELS-------------------- "),file = output_file_name, append = "TRUE")
    
    ##  Compare likelihood ratios (Poisson vs NB) ----
    
    pois_vs_NB<- lrtest(glmpoissonirr,nb)
    
    capture.output(print("Likelihood Ratio Test Poisson vs NB model   "),file = output_file_name, append = "TRUE")
    capture.output(print(pois_vs_NB),file = output_file_name, append = "TRUE")
    
    
    # Poisson AIC
    #capture.output(print(paste("AIC of Poisson model:",AIC_poisson)),file = output_file_name, append = "TRUE")
    
    #capture.output(print(paste("AIC of NB model:", AIC_NB)),file = output_file_name, append = "TRUE")
    
    capture.output(print("MODELS-------------------- "),file = output_file_name, append = "TRUE")
    
    capture.output(print("Output from Poisson model"),file = output_file_name, append = "TRUE")
    capture.output(print(summary(glmpoissonirr)),file = output_file_name, append = "TRUE")
    #  capture.output(print(anova(glmpoissonirr,test='Chi')),file = output_file_name, append = "TRUE")
    
    capture.output(print("Output from Neg Binomial model"),file = output_file_name, append = "TRUE")
    capture.output(print(summary(nb)),file = output_file_name, append = "TRUE")
    # capture.output(print(anova(nb,test='Chi')),file = output_file_name, append = "TRUE")
    
    
    
    #check poisson zero inflation - if found manually run zero inflated models
    print(i)
    pois_ZI <- check_zeroinflation(glmpoissonirr, tolerance = 0.05)
    
    capture.output(print("Poisson ZI test= "),file = output_file_name, append = "TRUE")
    
    capture.output(print(pois_ZI),file = output_file_name, append = "TRUE")
    #check NB zero inflation
    
    NB_ZI <- check_zeroinflation(nb, tolerance = 0.05)
    
    capture.output(print("NB ZI test= "),file = output_file_name, append = "TRUE")
    capture.output(print(NB_ZI),file = output_file_name, append = "TRUE")
  }
  
  
}


# AMC data analysis ---------------------

AMC_human <- read_csv("Data/Human_mg_kg.csv") 

AMC_vet <- read_csv("Data/Animal_mg_kg.csv") %>%
  filter(grepl("Belgium",Country))



#correlation tests human amc -------------

# for Belgium -------------------
#Normality check
qqnorm(AMC_human$Year, pch =1, frame = FALSE)
qqline(AMC_human$Year, col = "steelblue", lwd = 2)

qqnorm(AMC_human$`Volume (mg/kg)`, pch =1, frame = FALSE)
qqline(AMC_human$`Volume (mg/kg)`, col = "steelblue", lwd = 2)

qqPlot(AMC_human$`Volume (mg/kg)`)   # one outlier

#Shapiro test: if the  p-values are greater than the significance level 0.05 => the distribution of the data are not significantly different from normal distribution
# Shapiro-Wilk normality test for Year_simple
shapiro.test(AMC_human$Year) #p = 0.6704 --> can treat as normally distributed

# Shapiro-Wilk normality test for Value
shapiro.test(AMC_human$`Volume (mg/kg)`) # p =  0.04279--> can't treat as normally distributed

# #Pearson (parametric test, assumes linearity and normality) if p-value is less than 0.05. We can conclude that Year_simple and Value are significantly correlated with a correlation coefficient of <cor> and a p-value of <p-value>.
# PcorBelgium <- cor(AMC_human$Year, AMC_human$`Volume (mg/kg)`, method = "pearson")
# PcortestBelgium <- cor.test(AMC_human$Year, AMC_human$`Volume (mg/kg)`, method = "pearson")
# PcorBelgium
# PcortestBelgium



#Kendall (non-parametric test) if p-value is less than 0.05. We can conclude that Year_simple and Value are significantly correlated with a correlation coefficient of <tau> and a p-value of <p-value>.
KcorBelgium <- cor(AMC_human$Year, AMC_human$`Volume (mg/kg)`, method = "kendall")
KcortestBelgium <- cor.test(AMC_human$Year, AMC_human$`Volume (mg/kg)`, method = "kendall")
KcorBelgium
KcortestBelgium

# tau 
# -0.6323529   p-value = 0.0001949

#Spearman (non-parametric test) if p-value is less than 0.05. We can conclude that Year_simple and Value are significantly correlated with a correlation coefficient of <rho> and a p-value of <p-value>.
ScorBelgium <- cor(AMC_human$Year, AMC_human$`Volume (mg/kg)`, method = "spearman")
ScortestBelgium <- cor.test(AMC_human$Year, AMC_human$`Volume (mg/kg)`, method = "spearman")
ScorBelgium
ScortestBelgium

# rho 
# -0.8382353           p-value = 1.045e-05

# ---> negative correlation ***

# for EU - from JAMRAI data --------------

JIACRA_historic_human <- read_csv("Data/JIACRA_historic_human.csv")


JIACRA_historic_human_EU <- JIACRA_historic_human %>% 
  filter(grepl("EU", Country)) %>%
  mutate(icon = "",
          Country = "EU",
          signif_level = "") %>%
  dplyr::select(Year, Humans_mgkg,Country,icon,signif_level) %>%
  



# make dataset with label

AMC_human_result <- AMC_human %>%
  mutate(Humans_mgkg = `Volume (mg/kg)`) %>%
  dplyr::select(Year, Humans_mgkg,Country) %>%
  mutate(icon =  "downward_arrow",
         signif_level = "***")

# write.csv(AMC_human_result,"AMC_human_results.csv")
# write.table(JIACRA_historic_human_EU, file = "AMC_human_results.csv",
#             sep=",",  col.names=FALSE, append = T)

#correlation tests vet amc -------------

#Normality check
qqnorm(AMC_vet$Year, pch =1, frame = FALSE)
qqline(AMC_vet$Year, col = "steelblue", lwd = 2)

qqnorm(AMC_vet$Animals_mgkg, pch =1, frame = FALSE)
qqline(AMC_vet$Animals_mgkg, col = "steelblue", lwd = 2)

qqPlot(AMC_vet$Animals_mgkg)   # one outlier

#Shapiro test: if the  p-values are greater than the significance level 0.05 => the distribution of the data are not significantly different from normal distribution
# Shapiro-Wilk normality test for Year_simple
shapiro.test(AMC_vet$Year) #p = 0.7205 --> can treat as normally distributed

# Shapiro-Wilk normality test for Value
shapiro.test(AMC_vet$Animals_mgkg) # p =  0.2131--> can treat as normally distributed

#Pearson (parametric test, assumes linearity and normality) if p-value is less than 0.05. We can conclude that Year_simple and Value are significantly correlated with a correlation coefficient of <cor> and a p-value of <p-value>.
PcorBelgium_vet <- cor(AMC_vet$Year, AMC_vet$Animals_mgkg, method = "pearson")
PcortestBelgium_vet <- cor.test(AMC_vet$Year, AMC_vet$Animals_mgkg, method = "pearson")
PcorBelgium_vet
PcortestBelgium_vet

#cor = -0.9640277     p-value = 0.0004623


#Kendall (non-parametric test) if p-value is less than 0.05. We can conclude that Year_simple and Value are significantly correlated with a correlation coefficient of <tau> and a p-value of <p-value>.
KcorBelgium_vet <- cor(AMC_vet$Year, AMC_vet$Animals_mgkg, method = "kendall")
KcortestBelgium_vet <- cor.test(AMC_vet$Year, AMC_vet$Animals_mgkg, method = "kendall")
KcorBelgium_vet
KcortestBelgium_vet

# tau 
# -0.9047619  p-value = 0.002778

#Spearman (non-parametric test) if p-value is less than 0.05. We can conclude that Year_simple and Value are significantly correlated with a correlation coefficient of <rho> and a p-value of <p-value>.
ScorBelgium_vet <- cor(AMC_vet$Year, AMC_vet$Animals_mgkg, method = "spearman")
ScortestBelgium_vet <- cor.test(AMC_vet$Year, AMC_vet$Animals_mgkg, method = "spearman")
ScorBelgium_vet
ScortestBelgium_vet

# rho 
# -0.9642857            p-value = 0.002778

# ---> negative correlation *** (as normally distributed take Pearson correlation)

# europe from JIACRA --------

AMC_vet_EU <- read_csv("Data/Animal_mg_kg.csv") %>%
  filter(grepl("EU",Country)) %>%
  filter(!grepl("Iceland", Country)) %>%
  mutate(icon = "",
         Country = "EU",
         signif_level = "") %>%
  dplyr::select(Year, Animals_mgkg,Country,icon,signif_level)

  
  # make dataset with label for veterinary
  
  AMC_vet_result_Belgium <- AMC_vet %>%
  dplyr::select(Year, Animals_mgkg,Country) %>%
  mutate(icon =  "downward_arrow",
         signif_level = "***")
  
  AMC_vet_results <- rbind(AMC_vet_result_Belgium,AMC_vet_EU)

# write.csv(AMC_vet_results,"AMC_vet_results.csv")
