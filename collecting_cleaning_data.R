#-----------collecting and cleaning data ---------------

#script to process data if downloaded following instructions document

#here made for Belgium example, to run for your country you need to:
# lines 43-44 adapt "Belgium" and "BE"
# lines 129 adapt "Belgium"


#1. load libraries ---------------
library(tidyverse)
library(here)

#2. load data ------------------


#2a. load and clean human data ----------

ECDC_raw <-  read_csv("Data/ECDC_surveillance_data_Antimicrobial_resistance.csv",
                      na = c("", "NA", "-"),
                      trim_ws = TRUE
)

ECDC_data <- ECDC_raw %>%
  distinct() %>%
  separate(col = Population, into = c("Pathogen", "Antimicrobial"), sep = "\\|", remove = TRUE) %>%
  dplyr::select(-c(Unit,TxtValue,RegionCode)) %>%
  pivot_wider(names_from = Indicator, values_from = NumValue) %>%
  mutate(
    Year = Time,
    Sample_size = `Total tested isolates`,
    Percent_resistant = `R - resistant isolates, percentage`,
    Number_resistants = `R - resistant isolates`,
    Region = RegionName
  ) %>%
  dplyr::select(-c(`I - 'susceptible, increased exposure' isolates`,`S - susceptible isolates`,
                   `Completeness age`,`Completeness gender`,`Penicillin non-wild-type isolates, percentage`,
                   Time, `R - resistant isolates`, `R - resistant isolates, percentage`,
                   `Total tested isolates`, RegionName))

# make Slovenia dataframe

ECDC_data_SI <- ECDC_data %>%
  filter(grepl("Slovenia",Region), # select country data
         grepl("Escherichia", Pathogen), # select pathogen(s) to consider
         grepl("Aminopenicill|Third-gene|Fluoroqu", Antimicrobial))%>% #select antibiotics relevant to intersectoral comparisons
  mutate(Surveillance = "EARS",
         Host = "human_Blood_CSF") %>%
  select(Pathogen, Antimicrobial, Year, Sample_size, Percent_resistant, Surveillance, Host, Region)


# to make comparisons with EU average and neighbouring countries:

ECDC_data_EU <- ECDC_data %>%
  filter(grepl("Aminopenicill|Third-gene|Fluoroqu", Antimicrobial)) %>% #select antibiotics relevant to intersectoral comparisons
  group_by(Pathogen,Antimicrobial,Year) %>%
  summarise(Sample_size = sum(as.numeric(Sample_size, na.rm = T)),
            Number_resistants = sum(Number_resistants, na.rm = T))%>%
  mutate(Percent_resistant = Number_resistants/Sample_size*100,
          Surveillance = "EARS",
          Host = "human_Blood_CSF",
         Region = "Europe") %>%
  select(Pathogen, Antimicrobial, Year, Sample_size, Percent_resistant, Surveillance, Host, Region)


# make neighbours dataframe - if you want to compare to neighbouring countries
# ECDC_data_neighbours <- ECDC_data %>%
#   filter(grepl("Germany|France|Luxembourg|Netherlands",Region))%>%
#   filter(!(Antimicrobial == "Data Quality")) %>%
#   group_by(Pathogen,Antimicrobial,Year) %>%
#   summarise(Sample_size = sum(as.numeric(Sample_size, na.rm = T)),
#             Number_resistants = sum(Number_resistants, na.rm = T))%>%
#   mutate(Percent_resistant = Number_resistants/Sample_size*100,
#          Region = "Neighbours",
#          Surveillance = "EARS",
#          Matrix = "Blood_CSF")
# # combine
# ECDC_data_combined <- rbind(ECDC_data_EU,ECDC_data_neighbours)

#2b. load animal data ----------

# ── Load a single "AMR - 2025 Interactive dashboard_BE_*.csv" file ────────────
# These files are UTF-16 encoded with a two-row header:
#   row 1 — reporting year (repeated per pair of columns)
#   row 2 — "Antimicrobial substance" | "Occurrence of resistance" | "Number of isolates tested"
# Returns a tidy long data frame with columns:
#   animal, antimicrobial, year, occurrence_pct (0-100), n_isolates
load_amr_2025 <- function(path) {
  raw <- read_csv(
    path,
    locale         = locale(encoding = "UTF-16"),
    col_names      = FALSE,
    col_types      = cols(.default = col_character()),
    show_col_types = FALSE
  )
  
  # Extract animal label from filename (e.g. "broilers", "calves", "fattening pigs")
  animal <- basename(path) %>%
    str_extract("(?<=_.._).+(?=\\.csv$)") %>%
    str_replace_all("_", " ")
  region <- basename(path) %>%
    str_extract("(AMR - 2025 Interactive dashboard_).+(?=\\.csv$)")
  
  # Build one-row column names by forward-filling years across paired columns
  years <- tibble(yr = unlist(raw[1, ])) %>%
    mutate(yr = if_else(yr == "Reporting year", NA_character_, yr)) %>%
    fill(yr, .direction = "down") %>%
    pull(yr)
  
  metrics   <- unlist(raw[2, ])
  col_names <- if_else(
    metrics == "Antimicrobial substance",
    "Antimicrobial",
    paste0(years, "_", metrics)
  )
  
  # Drop header rows, pivot to long, clean types
  raw[-c(1, 2), ] %>%
    setNames(col_names) %>%
    filter(!is.na(Antimicrobial), trimws(Antimicrobial) != "") %>%
    pivot_longer(
      cols      = -Antimicrobial,
      names_to  = c("year", "metric"),
      names_sep = "_",
      values_to = "value"
    ) %>%
    mutate(
      Host = animal,
      Region = if_else(grepl("EU",region),"Europe","Slovenia"),
      Year   = as.integer(year),
      value  = as.numeric(str_remove(value, "%|,"))
    ) %>%
    pivot_wider(names_from = metric, values_from = value) %>%
    rename(
      Percent_resistant = `Occurrence of resistance`,
      Sample_size     = `Number of isolates tested`
    ) %>%
    select(Host, Antimicrobial, Year, Percent_resistant, Sample_size,Region)
}

# ── Load all  BE and EU dashboard files and combine ────────────────────────────
load_all_amr_2025 <- function(data_dir = here::here("Data")) {
  list.files(data_dir, pattern = "^AMR - 2025.*\\.csv$", full.names = TRUE) %>%
    map(load_amr_2025) %>%
    bind_rows()
}

# Usage:
 EFSA_amr_2025 <- load_all_amr_2025() %>%
   mutate(Surveillance = "EFSA",  # add identifiers to combine with human dataset
          Pathogen = "Escherichia coli" ) %>% #,
      #    Region = "Belgium") %>% # add identifiers to combine with human dataset
   #select antibiotics relevant to comparison and rename as per ECDC
   mutate(Antimicrobial = case_when(
     grepl("AMP",Antimicrobial) ~ "Aminopenicillins",
     grepl("CIP",Antimicrobial) ~ "Fluoroquinolones",
     grepl("TET",Antimicrobial) ~ "Tetracyclines",
     grepl("CTX",Antimicrobial) ~ "Third-generation cephalosporins"
   )) %>%
   filter(grepl("Aminopenicill|Third-gene|Fluoroqu", Antimicrobial))%>% #select antibiotics relevant to intersectoral comparisons
   select(Pathogen, Antimicrobial, Year, Sample_size, Percent_resistant, Surveillance, Host, Region) # columns to make human data



#3. combine data ------------

 AMR_comparative_interactive <- rbind(ECDC_data_SI,ECDC_data_EU,EFSA_amr_2025)

 write_csv(AMR_comparative_interactive, "Data/combined_data_for_analysis.csv")
 

 
 

 