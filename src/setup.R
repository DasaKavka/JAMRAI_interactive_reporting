# === setup.R — libraries, fonts/icons, ggplot theme ===
# Sourced first by app.R.

library(shiny)
library(shinyjs)
library(shinydashboard)
# library(bs4Dash)
# library(fresh)
library(shinyWidgets)
library(ggspatial)
library(ggrepel)
library(tidyverse)
library(sf)
library(leaflet)
library(RColorBrewer)
library(lwgeom)
library(gdalUtilities)
library(cowplot)
library(magick)
library(patchwork)
library(jpeg)
library(scales)
library(extrafont)
library(remotes)
library(extrafontdb)
library(ggpattern)
library(ggtext)
library(showtext)
library(flextable)
library(ggnewscale)
#library(shinyBS)
library(ftExtra)
library(gotop)
library(r2d3)

# 1. style -------------------------------------------------------------------


# adding fonts and icons to figures ------------------------------------

# Important step to enable showtext font rendering!
showtext_auto()

font_add('fa-solid', './font_awesome_font_files/fontawesome-free-6.4.0-desktop/otfs/Font Awesome 6 Free-Solid-900.otf')
font_add('ITC Avant Garde Gothic', './font_awesome_font_files/fontawesome-free-6.4.0-desktop/otfs/ITC_Avant_Garde_Gothic_Medium.otf')

upward_arrow <- "<span style='font-family:fa-solid;font-size:8pt'>&#xf062;</span>"
downward_arrow <- "<span style='font-family:fa-solid;font-size:8pt'>&#xf063;</span>" 
equals <- "<span style='font-family:fa-solid;font-size:8pt'>&#xf52c;</span>"   #" = " 
oscillate <- "<span style='font-family:fa-solid;font-size:8pt'>&#xf83e;</span>"   #" ~ "
arrow_right <-  "<span style='font-family:fa-solid;font-size:8pt'>&#xf061;</span>"
arrow_trend_up <- "<span style='font-family:fa-solid;font-size:8pt'>&#xe098;</span>"
arrow_trend_down <- "<span style='font-family:fa-solid;font-size:8pt'>&#xe097;</span>"




# 1B graph themes -----------------------------

moiras_graph_theme<- function(..., base_size = 12){theme(
  panel.background = element_blank(), #transparent panel bg
  plot.background = element_blank(), #transparent plot bg
  panel.grid.major.y =  element_line(colour = "#ccc6c4"), #grey y major gridlines
  panel.grid.major.x =  element_blank(), #remove major gridlines
  panel.grid.minor = element_blank(), #remove minor gridlines
  # legend.background = element_rect(fill='#001f3f'), #transparent legend bg
  legend.title = element_text(size = 10),
  legend.text = element_text(size = 9),
  #  legend.box.background = element_rect(fill='#001f3f'),
  text = element_text( family = "ITC Avant Garde Gothic"),
  axis.text = element_text(size = 10),
  #plot.background=element_blank(),#, , size = 10, family = "calibri"
  axis.title = element_text(size = 10),
  axis.ticks.x = element_blank(),
  axis.text.x = element_text(angle = 90,vjust = 0.5, hjust = 0.5),
  strip.background = element_blank(),
  strip.text = element_text(size = 10),
  legend.position = "top",
  legend.direction = "horizontal" 
)}
