# === data.R — load & prepare the AMR data (needs packages from setup.R) ===

comparative_AMR_data_raw <- read_csv("AMR_data_and_GLM_predictions_revised_method.csv") %>%
  mutate(Host = if_else(grepl("human",Host), "Human:Blood or CSF", str_to_sentence(Host))) %>%
  filter(!is.na(Host)) %>%
  mutate(label_icon = case_when(
    icon == "upward_arrow" ~ upward_arrow,
    icon == "downward_arrow" ~ downward_arrow,
    icon == "equals" ~ equals,
    icon == "oscilate" ~ oscillate,
    is.na(icon) ~ "",
    .default = ""),
    label_icon2 = case_when( 
      recent_years == "Up"  ~ arrow_trend_up,
      recent_years == "Down" ~ arrow_trend_down,
      recent_years == "" ~ "",
      is.na(recent_years) ~ "",
      .default = ""
    )) %>%
  mutate(adjusted_signif1 = if_else(is.na(signif_level_raw),"",signif_level_raw)) %>%
  mutate(label = paste(label_icon,adjusted_signif1,"",label_icon2, sep="")) %>%
  mutate(Year=as.numeric(Year)) %>%
  mutate( CI_upper = if_else( CI_upper>100,100, CI_upper))


host_species_resistance <- unique(comparative_AMR_data_raw$Host)

bact_species_resistance <- "Escherichia coli" #unique(comparative_AMR_data$Pathogen)


contributor_list<- read.csv("Data/contributor_report_details.csv",
                            sep = ";", header = T)

#resistance_data_types <- unique(contributor_list$Antimicrobial)


# add coordinates for trends label

y_coords <- comparative_AMR_data_raw %>%
  filter(Year == 2024) %>%
  group_by(Host,Pathogen, Antimicrobial)%>%
  mutate(rank = rank(Percent_resistant_predict))%>%
  ungroup() %>%
  mutate(y_coord = case_when(
    rank == 1 ~ (round(Percent_resistant_predict)+10),
    rank == 2 ~ (round(Percent_resistant_predict) - 10)
  )) %>%
  dplyr::select(Host,Pathogen,Antimicrobial,Region, y_coord)

comparative_AMR_data <- left_join(comparative_AMR_data_raw,y_coords, by = c("Host","Pathogen","Antimicrobial", "Region"))


# — load & prepare the AMC data (needs packages from setup.R) ===

  Human_AMC <-read_csv("AMC_human_results.csv") %>%
  mutate(label_icon = case_when(
    icon == "upward_arrow" ~ upward_arrow,
    icon == "downward_arrow" ~ downward_arrow,
    icon == "equals" ~ equals,
    icon == "oscilate" ~ oscillate,
    .default = ""
  )) %>%
  mutate(label = if_else((is.na(signif_level) | grepl("",signif_level)), label_icon, paste(label_icon,signif_level,sep=" ")))%>%
  mutate(Host = "Human",
         mg_kg = Humans_mgkg,
         Region = if_else(grepl("Belgium", Country), "Belgium", "Europe"))%>%
  select(-c(Humans_mgkg, Country))


Vet_AMC <-read_csv("AMC_vet_results.csv") %>%
  mutate(label_icon = case_when(
    icon == "upward_arrow" ~ upward_arrow,
    icon == "downward_arrow" ~ downward_arrow,
    icon == "equals" ~ equals,
    icon == "oscilate" ~ oscillate,
    .default = ""
  )) %>%
  mutate(label = if_else((is.na(signif_level) | grepl("",signif_level)), label_icon, paste(label_icon,signif_level,sep=" "))) %>%
  mutate(Host = "Animal",
         mg_kg = Animals_mgkg,
         Region = if_else(grepl("Belgium", Country), "Belgium", "Europe"))%>%
  select(-c(Animals_mgkg,Country))

Intersectoral_AMC = rbind(Human_AMC, Vet_AMC)

