# install_requirements.R

# a script to install packages required for other scripts within directory

required_packages <- c(
  # Équipe initiale
  "tidyverse", "here", "data.table", "magrittr", "AER", "MASS", 
  "COMPoissonReg", "performance", "DHARMa",
  
  # Nouvelle équipe (Shiny, Cartographie et Graphiques)
  "shiny", "shinyjs", "shinydashboard", "shinyWidgets",
  "ggspatial", "ggrepel", "sf", "leaflet", "RColorBrewer", 
  "lwgeom", "gdalUtilities", "cowplot", "magick", "patchwork", 
  "jpeg", "scales", "extrafont", "remotes", "extrafontdb", 
  "ggpattern", "ggtext", "showtext", "flextable", "ggnewscale", 
  "ftExtra", "gotop", "r2d3"
)

# Installe les packages manquants
missing_packages <- required_packages[!(required_packages %in% installed.packages()[,"Package"])]

if(length(missing_packages) > 0) {
  install.packages(missing_packages)
  message("Packages installés avec succès !")
} else {
  message("Tous les packages sont déjà installés.")
}