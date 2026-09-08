# — load & prepare the AMC data (needs packages from setup.R) ===

Human_AMC <- read_csv("AMC_human_results.csv") %>%
  mutate(
    label_icon = case_when(
      icon == "upward_arrow" ~ upward_arrow,
      icon == "downward_arrow" ~ downward_arrow,
      icon == "equals" ~ equals,
      icon == "oscilate" ~ oscillate,
      .default = ""
    )
  ) %>%
  mutate(
    label = if_else(
      is.na(signif_level) | grepl("", signif_level),
      label_icon,
      paste(label_icon, signif_level, sep = " ")
    )
  ) %>%
  mutate(
    Host = "Human",
    mg_kg = Humans_mgkg,
    Region = if_else(
      grepl("Slovenia", Country),
      "Slovenia",
      "Europe"
    )
  ) %>%
  select(
    Year, icon, signif_level, label_icon,
    label, Host, mg_kg, Region
  )


Vet_AMC <- read_csv("AMC_vet_results.csv") %>%
  mutate(
    label_icon = case_when(
      icon == "upward_arrow" ~ upward_arrow,
      icon == "downward_arrow" ~ downward_arrow,
      icon == "equals" ~ equals,
      icon == "oscilate" ~ oscillate,
      .default = ""
    )
  ) %>%
  mutate(
    label = if_else(
      is.na(signif_level) | grepl("", signif_level),
      label_icon,
      paste(label_icon, signif_level, sep = " ")
    )
  ) %>%
  mutate(
    Host = "Animal",
    mg_kg = Animals_mgkg,
    Region = if_else(
      grepl("Slovenia", Country),
      "Slovenia",
      "Europe"
    )
  ) %>%
  select(
    Year, icon, signif_level, label_icon,
    label, Host, mg_kg, Region
  )


Intersectoral_AMC <- rbind(Human_AMC, Vet_AMC)
