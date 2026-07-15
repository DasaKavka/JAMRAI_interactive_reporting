# # install necessary packages
# install.packages(c("devtools"))
# install the development version of leaflet from Github
# devtools::install_github(repo = "rstudio/leaflet")
# install.packages("leaflet")
# JAMRAI 2 — One Health AMR/AMC interactive reporting (Shiny app)
#
# Entry point. The app is split by concern so R / HTML(UI) / JS / CSS stay separate:
#
#   src/setup.R         libraries, fonts/icons, ggplot theme
#   src/data.R          load & prepare the AMR data
#   src/text_content.R  editorial / methodology HTML text
#   src/amr_module.R    reusable AMR chart block (filters+switches+slider+D3), a Shiny module
#   src/ui.R            UI: header, sidebar, tabs (defines `ui`) + loadingLogo helper
#   src/server.R        server logic (defines `server`)
#
#   www/amr_d3.js       interactive D3 chart (JavaScript, read server-side by r2d3)
#   www/amc_d3.js       interactive D3 chart (JavaScript, read server-side by r2d3)
#   www/app.js          page-level JS (loading-logo swap, header subtitle)
#   www/style2_2.css    styles
#
# Run with the "Run App" button, or shiny::runApp().


# Sourced in dependency order (setup → data/text → module → ui → server).
source("src/setup.R")
source("src/data.R")
source("src/text_content.R")
source("src/amr_module.R")
source("src/amc_module.R")
source("src/ui.R")
source("src/server.R")

##### Adapt for your country --> change "Belgium" and methodology in:

#Update the contributors logos in www file (“contributor_report_details.csv” in Data   who provides the data/link to their reports
#src/text_content.R ---> change text relating to Belgium/Belgian data collection etc.
#src/server.R --> change filters for Belgium e.g. line 44,65,88,112,135 and abbreviation table
#src/ui.R --> change selection buttons "Belgium" e.g. lines 121,122,


# # install necessary packages
# install.packages( pkgs = c( "devtools") )
# # install the development version of leaflet from Github
# devtools::install_github( repo = "rstudio/leaflet" )
#install.packages("leaflet")


# ***Contents ----------------------------------------------------------------

# 1. Load Library ---------------------------------------------------------
#install.packages("htmltools")
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

# 2. Load data ------------------------------------------------------------

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

# 3. Load Text ------------------------------------------------------------

Welcome_text <- "
Here you can add text to welcome readers and outline the context/link to reports, e.g. for Belgium:
<br/><br/>
Antimicrobial agents are vital for treating and preventing the spread of diseases.  However, pathogens like bacteria and fungi can develop resistance to these drugs, especially in the face of antimicrobial overuse and misuse. 
<br/><br/>
A key step in the fight against antimicrobial resistance is the careful monitoring of drug usage and resistance patterns. This surveillance is key to both developing and monitoring the effect of interventions such as optimal treatment guidelines and infection prevention and control programs.
<br/><br/>
In Belgium, antimicrobial consumption (AMC) and the emergence of resistance (AMR) is monitored in various settings including human medicine, food-producing animals, and the food supply chain. Additionally, data is collected on the sales of antimicrobial products for all animals and for non-medical use (for example in agriculture), as well as the detection of antimicrobial residues in the environment. As the results from these diverse programs are reported separately, it can be challenging to gain a clear overview of the trends in AMR and AMC across sectors in Belgium.
<br/><br/>
The BELMAP report aims to provide this overview - comprehensively summarising results and trends from existing surveillance programs from all sectors and directing readers to the detailed sector-specific reporting. Cross-sectoral collaboration also allows the BELMAP network to identify potential gaps and make recommendations for
improving future monitoring.
<br/><br/>
Visit the <a href='https://bit.ly/BELMAP2025'>interactive BELMAP report</a> to explore the most recent data on AMR and AMC in Belgium.
<br/><br/>
"


# keep methodologies for data, remove other texts

method_general <- "<b>Statistical analysis and reporting</b>
<br/><br/>
Plots were generated in R (version R- 4.2.1) using the ggplot2 package.
For each yearly observed percentage of samples testing resistant (number of resistant/total sample size * 100) or where
noted number of resistant cases per 1000 patient days), bars represent
the observed value. We used a Log-linear Poisson regression analysis to
evaluate the effect of time (year) on the number of instances
antimicrobial resistance occurred. An exposure variable (offset option
in R) was included in the model to indicate the number of times
resistance could have occurred in theory, i.e. sample size. In case of
overdispersion, quasi-Poisson or negative binomial analyses were
performed. The best fit regression is depicted by a line graph, with
ribbons representing the 95% confidence intervals, calculated based on
the link function of the glm (fit data +/- 2*Standard Error based on
link scale). Pearson (normally
distributed data) and Spearman correlation tests were performed to
explore the relation between the consumption of antimicrobial agents and
time.
<br/><br/>
Please note all trend analyses were performed using the <b>entire dataset</b>, thus while the axes scales of figures can be adjusted, changing the years of data visualised, the trend shown refers to the trend across the entire dataset. All statistical analyses were conducted in R and all code and data
are available on the <a href='https://github.com/BELMAP/BELMAP2023_analysis'>[BELMAP Github]</a>, along with the publication of all data from the report in the appendix (available to download on the Contributor page).
<br/><br/>
Symbols are included on figures to represent results of statistical
analyses:<br/><br/>"

Introduction_text3 <- "Results are indicated as *,** and *** for results with p-values
0.05<p<0.01, 0.01<p<0.001 and p<0.001, respectively. To enable clearer visualisation of trends, the scale of figures can be adapted using the 'Flexible scale' button. For resistance data from veterinary samples, standardised description of resistance levels will be applied, consistent with the <a href='https://www.efsa.europa.eu/en/efsajournal/pub/4036'>[EFSA criteria]</a>: rare= <0.1%, very low= 0.1% to 1.0%, low= 1% to 10.0%, moderate= 10.0% to 20.0%, high: 20.0% to 50.0%, very high: 50.0% to 70.0%, extremely high:> 70.0%. These terms are applied to all antimicrobials. However, the significance of a given level of resistance will depend on the antimicrobial in question and its importance in human and veterinary medicine."

Methodology_human_data_collection <-"
The epidemiological monitoring of AMR in humans in Europe is coordinated by :
<br/><br/>
• the European (EU) Antimicrobial Resistance Surveillance Network for
Belgium <a href='https://www.ecdc.europa.eu/en/about-us/networks/disease-networks-and-laboratory-networks/ears-net-data'>[('EARS-Net')].<br/>
<br/><br/>
<b>EARS-Net</b> <br/>
<a href='https://www.ecdc.europa.eu/en/about-us/networks/disease-networks-and-laboratory-networks/ears-net-data'>[EARS-Net]</a>
is the main EU epidemiological surveillance system for AMR, and its data
serve as important indicators on the occurrence and spread of AMR in
<a href='https://www.ecdc.europa.eu/en/%20surveillance-atlas-infectious-diseases'>[European countries]</a>.
On a yearly basis, this monitoring system collects and reports data from
European countries on AMR against relevant antimicrobials within
commonly occurring pathogens isolated from <b>clinical invasive samples
(blood and cerebrospinal fluid (CSF))</b> in humans. EARS-Net collects
such data on seven bacterial pathogens commonly causing infections in
humans: <i>Escherichia coli</i>, <i>K. pneumoniae</i>, <i>P. aeruginosa</i>, <i>Acinetobacter</i>
species, <i>S. pneumoniae</i>, <i>S. aureus</i>, <i>E. faecalis</i> and <i>E. faecium</i>.
EU member states are requested to participate in EARS-Net by EU
recommendation (Council Recommendation, 2009/C 151/01), with
<b>participation voluntary</b> for laboratories.
<br/>
In Belgium, national data is collected and submitted to the EU by the
'Healthcare-associated infections and antimicrobial resistance service'
of Sciensano (NSIH), through the <a href='https://www.sciensano.be/nl/projecten/europese-antimicrobiele-resistentie-surveillance-belgie'>['EARS-BE surveillance']</a>.
"



food_prod_methods <- "This dashboard uses AMR data coordinated by <a href='https://www.efsa.europa.eu/en/microstrategy/dashboard-antimicrobial-resistance'>['EFSA']</a>. Data from commensal <i>E. coli</i> isolated from healthy animals as a general indicator for resistance among food-producing animals. <i>E. coli</i> is an indicator bacterium that can be frequently isolated from all animal species. Resistance levels within <i>E. coli</i> reflect the magnitude of selective pressure exerted by antibiotics in the population, and can be used as an indicator of emergence and change in AMR in the population. Additionally, MRSA is monitored in different animal categories to map both the prevalence of this resistant zoonotic bacterium and its level of resistance to other antibiotics.
<br/><br/>
For commensal <i>E. coli</i> monitoring in Belgium, the Federal Agency for the Safety of the Food Chain (FASFC) has collected samples of caecal content at the slaughterhouse and fresh faeces at farm  annually since 2011 as part of a nationwide surveillance program. The following categories of food-producing animals are included: beef cattle (meat production, faeces sampled at the farm level), and veal calves, broiler chickens and fattening pigs sampled at the slaughterhouse. The sampling and isolation of indicator <i>E. coli</i> strains are performed according to standardized technical instructions, details of which are available in the <a href='https://favv-afsca.be/nl/antibioticaresistentie-resultaten#sciensano'>[reports of FASFC]</a>.
<br/><br/>
<i>E. coli</i> bacteria are tested for susceptibility to ciprofloxacin, cefotaxime, colistin and 12 other antibiotics, as determined by European legislation (2013/652/EU and 2020/1729). Since 2014, all the isolates showing resistance to a third generation cephalosporin are considered potential beta-lactamase producing <i>E. coli</i>, and are analyzed in detail for their beta-lactamase activity. For more details please see the <a href='https://favv-afsca.be/nl/antibioticaresistentie-resultaten#sciensano'>[Sciensano-FASFC reports.]</a>
<br/><br/>
The surveillance of MRSA follows a 3-year cycle and includes farm samples (pooled nasal swabs) from the poultry, cattle, or pig sector, depending on the year. AMR testing of MRSA strains is detailed in the reports available on the FASFC website. The method used to isolate MRSA strains from pooled nasal swabs changed in 2022 to the so-called 1-S isolation method according to the <a href='https://www.eurl-ar.eu/CustomerData/Files/Folders/21-protocols/430_mrsa-protocol-final-19-06-2018.pdf'>[EURL-AR protocol version from 2018]</a>, in which the second enrichment step with cefoxitin and aztreonam applied for the previous monitoring years (the so-called 2-S isolation method)  is excluded.   The confirmed MRSA isolates are spa-typed by retrieving, from the whole-genome sequencing (WGS), the repetitive region of the <i>spa</i> gene encoding for the staphylococcal protein A, and categorized as livestock associated (LA) MRSA if they are associated to the <i>S. aureus</i> clonal complex CC398 through WGS.
<br/><br/>"

AMR_text_outline <- "Here you can add Text describing the findings - this can reactive to what is selected"

AMR_fig_text_outline <- "Here you can add Text describing the figure - this can reactive to what is selected"


# 4. Define UI ------------------------------------------------------------

# Define UI 

# 4A. Define header, logo and loading logo -------------------------------------------

loadingLogo <- function(href, src, loadingsrc, height = NULL, width = NULL, alt = NULL) {
  tagList(
    tags$head(
      tags$link(rel = "stylesheet", type="text/css", href="www/style2_2.css"),
      tags$script(
        "setInterval(function(){
                     if ($('html').attr('class')=='shiny-busy') {
                     $('div.busy').show();
                     $('div.notbusy').hide();
                     } else {
                     $('div.busy').hide();
                     $('div.notbusy').show();
           }
         },100)"),
      tags$style(HTML(
        '* {font-family: "ITC Avant Garde Gothic";}'))),
    tags$a(href=href,
           div(class = "busy",
               img(src=loadingsrc,height = 50, width = 180, alt = alt)),
           div(class = 'notbusy',
               img(src = src, height = 50, width = 180, alt = alt))
    )
  )
}



# 4b. Define UI sidebar --------------------------------------------------------------
siteHeader<- dashboardHeader(title = "JAMRAI 2 : Interactive One Health AMR/AMC Reporting")

sidebar <- dashboardSidebar(
  
  tagList(
    tags$head(
      tags$link(rel = "stylesheet", type="text/css", href="www/style2_2.css"))),
  
  sidebarMenu(id= "sbmenu",
              menuItem("Welcome", tabName = "Welcome", icon = icon("door-open", lib = "font-awesome", tabName = "Welcome")),
              menuItem("Methodology", tabName = "Methodology", icon = icon("calculator", lib = "font-awesome", tabName = "Methodology")),
              menuItem("AMR", icon = icon("bacteria", lib = "font-awesome"), tabName = "AMR"),
              menuItem("Contributors", icon = icon("server", lib = "font-awesome"), tabName = "contributors")
  )
)

body <- dashboardBody(
  tags$script(HTML('
      $(document).ready(function() {
        $("header").find("nav").append(\'<span class="myClass"> <br/>One Health antimicrobial resistance pilot dashboard</span>\');
      })
     ')),
 # tags$head(includeHTML("google-analytics.html")), # update if want to include google analytics for your report
  includeCSS("www/style2_2.css"),
  use_gotop(),
  tabItems(
    ## Welcome page tab ---------------------------------------------------------
    tabItem(tabName = "Welcome",
            fluidPage(
              fluidRow(
                column(12,
                       h2("Welcome"),
                       htmlOutput("Welcome_text")     # add editorial paragraphs
                )
              )
            )
            
    ),
    
    #Methodology summary tab ------------------------------------------------
    
    tabItem(tabName = "Methodology",
            fluidPage(
              fluidRow(
                tabBox(width = NULL, 
                       #title = "First tabBox",
                       # The id lets us use input$tabset1 on the server to find the current tab
                       id = "tabsetmethod",  # height = "3000px",
                       
                       tabPanel("Introduction", icon = icon("house", lib = "font-awesome"),width = NULL, 
                                # Intro text 
                                fluidRow(width = NULL,
                                         column(12, offset = 0.5,
                                                htmlOutput("Introduction_text1"),
                                                box(
                                                  width = 12,
                                                  collapsible = TRUE,
                                                  title ="Data collection for human samples",
                                                  htmlOutput("Methodology_human_data_collection"),
                                                  collapsed = TRUE),
                                                # box(
                                                #   width = 12,
                                                #   collapsible = TRUE,
                                                #   title ="Data collection for Campylobacter and Salmonella",
                                                #   htmlOutput("Zoonoses_methodology"),
                                                #   collapsed = TRUE),
                                                box(
                                                  width = 12,
                                                  collapsible = TRUE,
                                                  title ="Data collection from commensals in healthy food producing animals and the food chain",
                                                  htmlOutput("food_prod_methods"),
                                                  collapsed = TRUE) #,
                                                # box(
                                                #   width = 12,
                                                #   collapsible = TRUE,
                                                #   title ="Data collection from veterinary pathogens",
                                                #   htmlOutput("Vetpath_method"),
                                                #   collapsed = TRUE)
                                         )))
                )
              )
            )
    ),
    
    # AMR Tab layout -----------------------------------------------
    tabItem(tabName = "AMR",
            fluidPage(
              fluidRow(
                column(4,
                       radioButtons("antibiotic", label = h3("Select Antibiotic"),
                                    choices = list("Aminopenicillins" = "Aminopenicillins",
                                                   "Fluoroquinolones" = "Fluoroquinolones",
                                                   "Third-generation cephalosporins" =   "Third-generation cephalosporins"
                                                   ),
                                    selected = c("Aminopenicillins"))),
                column(4,
                       awesomeCheckboxGroup("host", label = h3("Select Species"),
                                            choices = host_species_resistance,
                                            selected = c("Human:Blood or CSF"))),
                column(4,
                       awesomeCheckboxGroup("bact", label = h3("Select Pathogen"),
                                            choices = c( "E. coli" = "Escherichia coli"),
                                            selected = c("Escherichia coli"))),
              column(4,
                     awesomeCheckboxGroup("region", label = h3("Select Region"),
                                          choices = c("Slovenia","Europe"),
                                          selected = c("Slovenia","Europe")))),
              
              fluidRow(plotOutput("amr_fig",height = "800px"),
                       fluidRow(
                         column(2,
                         materialSwitch(
                           inputId = "amr_ss1",
                           label = "Show Slovenian sample sizes",
                           status = "primary",
                           right = TRUE
                         ) ),
                         column(2,
                                materialSwitch(
                                  inputId = "Zoom_switch_amr1",
                                  label = "Zoom in scale",
                                  status = "primary",
                                  right = TRUE
                                )),
                         column(2,
                                sliderInput("year_amr1", label = "Select Years", min = 2000,
                                            max = 2024, value = c(2000, 2024),sep = "")),
                                  htmlOutput("AMR_fig_text")),
                             fluidRow(htmlOutput("AMR_text")
                       )))),
    
    
    #  contributors tab layout ----------------------------------------------------
    tabItem(tabName = "contributors",
            fluidPage(
              fluidRow(
                column(12,
                       h2(textOutput("contrib_page_title"))
                )),
              fluidRow(
                column(4,
                       selectInput("chose_analysis_type", label = h4("Select analysis"), 
                                   choices = c("Human- E. coli",
                                               # "Human- Salmonella spp.",
                                               # "Human- Neisseria gonorrhoeae",
                                               # "Human- Shigella spp.",
                                               # "Human- Campylobacter",
                                               # "Zoonotic pathogens in the foodchain",
                                               "Healthy food producing animals - E. coli"), #,
                                               # "Veterinary Pathogen-E. coli in beef cattle",
                                               # "Veterinary Pathogen-E. coli in chickens",
                                               # "Veterinary Pathogen-E. coli in swine",
                                               # "Veterinary Pathogen-E. coli in bovine mastitis"), 
                                   selected = "Human- E. coli"),
                       imageOutput("Contributor_logo"), height = "200px"),
                column(8,
                       htmlOutput("contributor_report_link")
                )) #,
              # fluidRow(
              #   column(12,
              #          h3("Contributors to the BELMAP report:"),
              #          uiOutput("Contributors_table") 
              #   ))
              ))
  )       
)

# 5. UI Body -----------------------------------------------------------------

# Put them together into a dashboardPage
ui <- dashboardPage(
  # freshTheme = theme,
  #  tags$script(src = "https://kit.fontawesome.com/7d2f617ce8.js"),
  
  #5a. UI Header -------------------------------------------------------------
  # skin = "green", 
  dashboardHeader(title = loadingLogo('https://eu-jamrai.eu/',
                                      
                                      'Eujamrai_Rectangular_Transparent_Color.png',
                                      'Eujamrai_Rectangular_Transparent_Color.png')),
  sidebar,
  body
)



# 6. Define server --------------------------------------------------------

# Define server logic required to draw a histogram

server <- function(input, output, session) {
  # 6A. Define reactive values and data ----------------------------------------------------------
  # ***define global ---------------------------------------------------------------
  global <- reactiveValues(
    
    # human AMR reactive values
    amr_select_bact = "Escherichia coli",
    amr_select_antib = "Aminopenicillins",
    amr_select_host = "Human:Blood or CSF",
    amr_select_region = c("Slovenia","Europe"),
    # AMR_text = paste(h_ec_text),
    # AMR_fig_text = h_ec_fig_leg,
    amr_fig_data = comparative_AMR_data %>%
      filter(grepl("Escherichia coli", Pathogen),
             grepl("Aminopenicillins", Antimicrobial)) %>%
      mutate(Sample_size = "") ,
    amr_sample_size = "FALSE",
    
    
    
    # define contributors reactive
    chose_analysis_type = "Human- E. coli",
    Contributor = "IMI, NLZOH",
    Report = "EARS-be and NSIH-AMR",
    Report_website  = "https://www.sciensano.be/en/about-sciensano/sciensanos-organogram/healthcare-associated-infections-and-antimicrobial-resistance"
    
  )
  
  
  # 6A.2 define AMR reactive values ---------------------------------------
  
  # 6A.2.A define human pathogen AMR reactive values --------------------------
  
  
  # reactive event : chose pathogen
  observeEvent(eventExpr = {
    input$bact
  } ,{
    global$amr_select_bact <-  input$bact
    if(global$amr_sample_size == TRUE){
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = if_else(grepl("Slovenia",Region),as.character(Sample_size.x), "")) %>%
        filter(grepl(paste( global$amr_select_bact, collapse = "|"), Pathogen),               
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    } else {
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = "") %>%
        filter(grepl(paste( global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    }
  })
  
  observeEvent(eventExpr = {
    input$region
  } ,{
    global$amr_select_region <-  input$region
    if(global$amr_sample_size == TRUE){
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = if_else(grepl("Slovenia",Region),as.character(Sample_size.x), "")) %>%
        filter(grepl(paste( global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    } else {
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = "") %>%
        filter(grepl(paste( global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    }
  })
  
  # reactive event: chose antibiotic
  
  observeEvent(eventExpr = {
    input$antibiotic
  } ,{
    global$amr_select_antib <-  input$antibiotic
    if(global$amr_sample_size == TRUE){
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = if_else(grepl("Slovenia",Region),as.character(Sample_size.x), "")) %>%
        filter(grepl(paste( global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    } else {
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = "") %>%
        filter(grepl(paste(global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    }
  })
  
  # reactive event : chose host
  
  
  observeEvent(eventExpr = {
    input$host
  } ,{
    global$amr_select_host <-  input$host
    if(global$amr_sample_size == TRUE){
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = if_else(grepl("Slovenia",Region),as.character(Sample_size.x), "")) %>%
        filter(grepl(paste( global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    } else {
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = "") %>%
        filter(grepl(paste(global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    }
  })
  # reactive event: chose year
  
  #reactive event: sample size shown
  observeEvent(eventExpr = {
    input$amr_ss1
  } ,{
    global$amr_sample_size <-  input$amr_ss1
    if(global$amr_sample_size  == TRUE){
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = if_else(grepl("Slovenia",Region),as.character(Sample_size.x), "")) %>%
        filter(grepl(paste(global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    } else {
      global$amr_fig_data = comparative_AMR_data %>%
        mutate(Sample_size = "") %>%
        filter(grepl(paste(global$amr_select_bact, collapse = "|"), Pathogen),
               grepl(paste( global$amr_select_region, collapse = "|"), Region),
               grepl(global$amr_select_antib, Antimicrobial),
               grepl(paste(global$amr_select_host, collapse = "|"), Host))
    }
  })
  
  
  # 6.A 3 define reactive value contributors ----------------------------------
  
  
  observeEvent(eventExpr = {
    input$chose_analysis_type
  } ,{
    global$chose_analysis_type <- input$chose_analysis_type
    global$Contributor <- unique(subset(contributor_list, Analysis == global$chose_analysis_type, select =Contributor))
    global$Report <- unique(subset(contributor_list, Analysis == global$chose_analysis_type, select =Report))
    global$Report_website  <-unique(subset(contributor_list, Analysis == global$chose_analysis_type, select =website))
    
    
  })
  # 
  # Bactchoices <- reactive({case_when(
  #   input$antibiotic=="Ciprofloxacin" ~ c( "Escherichia coli","Neisseria gonorrhoeae","invasive Salmonellosis",                                 
  #                                          "Shigella spp." ,"Campylobacter jejuni", "Salmonella Typhimurium",                     
  #                                          "Salmonella Derby","Salmonella Enteritidis","Salmonella Infantis",                        
  #                                          "Salmonella Paratyphi B Var, L(+) Tartrate+","Campylobacter coli","hemolytic Escherichia coli"),
  #   input$antibiotic=="Colistin" ~ c("Escherichia coli",rep("",11))
  # )}) 
  
  # observeEvent({input$antibiotic},{
  #   updateAwesomeCheckboxGroup(session, "bact",  
  #                              label = "Select Pathogen", choices = Bactchoices(), 
  #                              selected = "Escherichia coli")
  # })
  
  #7. make reactive figures ----------------------------------------------------------
  
  
  output$Introduction_fig2 <-renderPlot({
    
    explaining_graphs <- tribble(
      ~x , ~ y, ~x1, ~Label, ~Label1,
      1, 2.5, 1.5,  upward_arrow, "represents an increasing trend",
      1, 2, 1.5, downward_arrow, "represents a decreasing trend",
      1, 1.5, 1.5, oscillate, "represents data with no significant increasing or decreasing trend, but with notable variation-\nhere defined as data for which the data range is greater than 25% of the mean",
      1, 1, 1.5, equals, "indicate no increasing or decreasing trend, without large variation (range less than 25% of the mean)."
      
    )
    
    ggplot(explaining_graphs)+
      geom_richtext(aes(x = x, y = y, label = Label),
                    fill = "#078BAD", stat = "unique",
                    colour= "white", show.legend = FALSE)+
      geom_text(aes(x = x1, y = y, label = Label1), colour = "#078BAD", size = 4,
                family = "ITC Avant Garde Gothic",hjust = 0)+
      theme(text = element_blank(),
            axis.ticks = element_blank(),
            panel.background = element_blank(), #transparent panel bg
            plot.background = element_blank(), #transparent plot bg
            panel.grid.major =  element_blank(), #grey y major gridlines
            panel.grid.minor = element_blank())+ #remove minor gridlines)
      ylim(0.9,2.6)+xlim(0.999,7)
    
  })
  
  
  
  output$Abbreviations_table <-  renderUI( {
    
    Abbreviations <- tribble(  
      ~Abbreviation, ~Definition,
      "3GC", "3rd Generation Cephalosporins",
      "AMC", "Antimicrobial Consumption",
      "AMU", "Antimicrobial Use",
      "AMR", "Antimicrobial Resistance",
      "AMCRA", "AntiMicrobial Consumption and Resistance in Animals",
      "ARSIA", "Association Régionale de Santé et d’Identification Animales",
      "ATC", "Anatomical Therapeutic Chemical classification",
      "BAPCOC", "Belgian Antibiotic Policy Coordination Committee",
      "BD100", "Treatment days ('Behandlingdagen, BD') out of 100 days present on the farm",
      "BeH-SAC", "Belgian Hospitals - Surveillance of AMC",
      "BelVet-SAC", "Belgian Veterinary Surveillance of Antibacterial Consumption",
      "BSI", "Blood stream infections",
      "CRKP", "Carbapenem-Resistant Klebsiella pneumoniae",
      "CI", "Confidence Interval",
      "CRE", "Carbapenem Resistant Enterobacterales",
      "CRPA", "Carbapenem-resistant Pseudomonas aeruginosa",
      "CPE", "Carbapenemase Producing Enterobacterales",
      "CSF", "Cerebrospinal fluid",
      "DDD", "Defined Daily Dose",
      "DGZ", "Dierengezondheidszorg Vlaanderen",
      "DID", "Defined Daily Dose per 1000 inhabitants per day",
      "EARS-BE", "European Antimicrobial Resistance Surveillance Belgium",
      "EARS-NET", "European Antimicrobial Resistance Surveillance Network",
      "ECDC", "European Centre for Disease Prevention and Control",
      "ECOFF", "Epidemiological cut-off values",
      "EFSA", "European Food Safety Agency",
      "EMA", "European Medicines Agency",
      "ESAC-Net", "European Surveillance of Antimicrobial consumption network",
      "ESBL", "Extended spectrum beta-lactamase",
      "ESKAPE","Enterococcus faecium, Staphylococcus aureus, Klebsiella pneumoniae, Acinetobacter baumannii, Pseudomonas aeruginosa, and Enterobacter spp.",
      "ESVAC", "European Surveillance of Veterinary Antimicrobial Consumption",
      "EUCAST", "European Committee on Antimicrobial Susceptibility Testing",
      "FAMHP", "Federal Agency for Medicines and Health Products",
      "FASFC", "Federal Agency for the Safety of the Food Chain",
      "FQL", "Fluoroquinolones",
      "HABSI", "Healthcare-Associated Bloodstream Infections",
      "HAI-AMR", "Healthcare Associated Infections and Antimicrobial Resistance",
      "INAMI", "Institut National D’Assurance Maladie-Invalidité",
      "ICU", "Intensive Care Unit",
      "ILVO", "Instituut voor Landbouw-, Visserij- en Voedingsonderzoek",
      "IPD", "Invasive Pneumococcal Disease",
      "JIACRA", "Joint Inter-agency Antimicrobial Consumption and Resistance Analysis",
      "MALT", "Mucosa-Associated Lymphoid-Tissue",
      "MCC", "Milk Control Center Flanders",
      "MDR", "Multidrug resistance",
      "MDRO", "Multidrug Resistant Organism",
      "MIC", "Minimal Inhibitory Concentration",
      "MRGN", "Multi-resistant Gram-negative bacteria",
      "MRSA", "Methicillin resistant Staphylococcus aureus",
      "MSM", "Men who have sex with men",
      "NAP-AMR", "National Action Plan on Antimicrobial Resistance",
      "NIHDI", "National Institute for Health and Disability Insurance",
      "NSIH", "National Surveillance of Infections in Healthcare Settings",
      "NSIH-AMR", "National surveillance of antimicrobial resistance",
      "NTHi", "Non-typeable Haemophilus influenzae",
      "NRC", "National Reference Centre",
      "PNEC", "Predicted No Effect Concentration",
      "PPS", "Point-Prevalence Study",
      "PCV", "Pneumococcal Conjugate Vaccines",
      "RIZIV", "Rijksinstituut voor ziekte- en invaliditeitsverzekering",
      "SPW", "Service Public de Wallonie",
      "SWDE", "Société Wallonne des Eaux",
      "TC-MDRO", "Technical Committee Multidrug Resistant Organisms",
      "TMP-SMX", "Trimethoprim-sulfamethoxazole",
      "VMM", "Vlaamse Milieu  Maatschappij",
      "VRE", "Vancomycin Resistant Enterococci",
      "WGS", "Whole Genome Sequencing",
      "WHO", "World Health Organization"
    )
    
    
    ft_abbrev<- flextable(Abbreviations) %>%
      colformat_md()
    
    Abbreviations_flextable<- set_table_properties(ft_abbrev, width = 1, layout = "autofit")
    htmltools_value(Abbreviations_flextable)
  })
  
  
  output$amr_fig <- renderPlot({
    
    year_min <- min(input$year_amr1)
    year_max <- max(input$year_amr1)
    
    ymax <- if_else(input$Zoom_switch_amr1 == TRUE, ceiling(max(global$amr_fig_data$Percent_resistant, na.rm = TRUE)/10)*10,100)
    
    
    amr_fig_plot <-   global$amr_fig_data %>%
     # mutate(y_coord = 20) %>%
      ggplot(aes(label = label_icon))+
      geom_bar(aes(x=Year, y = as.numeric(Percent_resistant), fill = Region), stat="identity", position = "dodge")+
      geom_ribbon(aes(x=Year, ymin = CI_lower, ymax = CI_upper, y = Percent_resistant_predict, group = Region), alpha = 0.25)+
      geom_smooth(aes(x=Year, y = Percent_resistant_predict, colour = Region),stat = "identity")+
      scale_fill_manual(values = c("#078BAD", "#0FDBD5") )+
      scale_colour_manual(values = c("#078BAD", "#0FDBD5") )+
      facet_wrap( ~ Host, labeller = label_wrap_gen(width = 10, multi_line = T))+
      # geom_richtext( size = 16, hjust = 0, label.colour = NA) +
      scale_y_continuous(limits = c(-1,ymax), breaks = seq(0,ymax, length.out = 3))+
      scale_x_continuous(limits = c(year_min-1,year_max+2), breaks = seq(year_min,year_max,1))+
      geom_text(aes(x = Year, y = (ymax/100*90), label = Sample_size), colour = "black", size = 2, angle = 90, hjust = 1)+  #make this additional for interactive report
      geom_richtext(aes(x = year_max+1, y = y_coord,
                        fill = Region,
                        label = label), stat = "unique",
                    colour= "white", show.legend = FALSE)+
      # fill = NA, label.color = NA, # remove background and outline
      # label.padding = grid::unit(rep(0, 4), "pt")) +
      #  geom_text(aes(x = Year, y = 2, label = Sample_size.x), na.rm = TRUE, size = 2.5)+  #make this additional for interactive report
      labs(x="", y= "% Resistance")&
      moiras_graph_theme()
    # theme(strip.text = element_text(size = 9),
    #       axis.text = element_text(size = 9))
    amr_fig_plot
  })
  
  
  
  # 7.5 contributors figures and tables ---------------------------------------
  
  output$Contributors_table <-  renderUI( {
    
    
    Contributors_list <- tribble(
      ~Contributors,~` `,
      "AMCRA", "Fabiana Dal Pozzo, Bénédicte Callens and Wannes Vanderhaeghen",
      "ARSIA", "Marc Saulmont",
      "Brussels Environment", "Audrey Marescaux",
      "CHU Liège", "Cécile Meex",
      "DGZ and MCC", "Nadine Botteldoorn, Evelyne De Graef and Zyncke Lipkens",
      "NSIH-AMR/EARS-BE (Sciensano)", "Katrien Latour, Morgan Pearcy, and Aline Vilain",
      "BeH-SAC/ESAC-NET (Sciensano)", "Lucy Catteau, Elena Damian, Laura Bonacini and Boudewijn Catry ", 
      "FAMHP", "Antita Adriaens, Inge Vandenbulcke and Liesbeth Van Nieuwenhove",
      "FASFC", "Maude Lebrun",
      "FPS Public Health", "Annemie Vlayen, Vincent Dehon, Jennifer Pirotte",
      "","Katie Vermeersch, Mélissa Rousseau, Ivo Deckers, Christophe Vermeulen" ,
      "ISSep", "Leslie Crettels",
      "ILVO", "Geertrui Rasschaert",
      "National Reference Laboratory for AMR (Sciensano)", "François Bricteux, Cristina Garcia-Graells, Cécile Boland\n and Carole Kowalewicz",
      "NRC AMR in Gram-  Negative Bacteria (UCLouvain, Mont-Godinne)", "Olivier Denis and Daniel Huang",
      "NRC Campylobacter (LHUB-ULB)", "Delphine Martiny", 
      "NRC Clostridioides (UCLouvain)", "Ahalieyah Anantharajah",
      "NRC Enterococci (UZA)", "Veerle Matheeussen",
      "NRC Causative agents of mycosis (UZ and KU Leuven)", "Lize Cuypers and Katrien Lagrou",
      "NRC Haemophilus influenzae (LHUB - ULB)", "Delphine Martiny",
      "NRC Invasive Streptococcus pneumoniae (UZ and KU Leuven)", "Lize Cuypers and Stefanie Desmet ",
      "NRC Salmonella, Shigella and Mycobacteria (Sciensano)", "Pieter-Jan Ceyssens, Vanessa Mathys",
      "NRC Sexually Transmitted Infections (ITG)", "Irith De Baetselier, Dorien Van den Bossche", 
      "NRC Staphylococci (LHUB-ULB)", "Nicolas Yin",
      "Mycology and aerobiology (Sciensano)", "Hanne Debergh, Ann Packeu (Mycology)",
      "Société Publique de Gestion de l'Eau", "Rosalie Pype",
      "Service public de Wallonie", "Frédéric Hourlay, Elisabeth Chouters and Sven Abras",
      "Sciensano", "Brecht Devleesschauwer",
      "Statistical analysis and data compilation and editing (Sciensano)", "Moira Kelly, Margo Maex and Pieter-Jan Ceyssens",
      "TC-MDRO", "Lucy Catteau (Sciensano) and Olivier Denis (UCLouvain, Mont-Godinne)",
      "UGent", "Ilias Chantziaras",
      "Coordination of veterinary activities\n& veterinary epidemiology (Sciensano)", "Mickael Cargnel & Jean-Baptiste Hanon",
      "VMM","Philippe De Maesschalck and Ann De Meester"
      
    )
    
    
    ft_contrib<- flextable(Contributors_list) %>%
      colformat_md()
    
    contributors_flextable<-set_table_properties(ft_contrib, width = 1, layout = "autofit")
    
    htmltools_value(contributors_flextable)
  })
  
  
  #make title 
  
  output$contrib_page_title <- renderText({ "Where can I find out more about the data?" })
  
  #make contributors logo
  
  
  contributor_report<- reactive({
    contributor_list %>%
      filter(Analysis == global$chose_analysis_type)
  })
  
  
  # 
  # filename1 <- reactive({
  #   paste("www/", unique(contributor_report()$Contributor),"_logo.jpg", sep='')
  # })
  # 
  # 
  # filename2 <- reactive({
  #   paste("www/", unique(contributor_report()$Report),"_logo.jpg", sep='')
  # })
  # 
  
  
  
  
  output$Contributor_logo <- renderImage({
    
    #  image_file <- paste("www/", global$Contributor,"_logo.jpg", sep='')
    
    return(list(
      src = paste("www/", global$Contributor,"_logo.jpg", sep=''),
      filetype = "image/jpeg",
      height = 120,
      width = 300,
      href= global$Report_website
    ))
    
  }, deleteFile = FALSE)
  
  #make report logo 
  
  
  
  output$Report_logo <-  renderImage({
    image_file <- paste("www/", unique(contributor_report()$Report),"_logo.jpg", sep='')
    
    return(list(
      src = image_file,
      filetype = "image/jpeg",
      height = 500,
      width = 300
    ))
    
  }, deleteFile = FALSE)
  
  
  
  # TEXT OUTPUTS -----------------------------------------   
  #editorial text output ------------------------------
  
  output$Welcome_text <- renderText(Welcome_text)
  
  # text outputs intro/methods -----------------------------
  
  output$Introduction_text1 <- renderText(method_general)
  
  
  output$Methodology_human_data_collection <- renderText({
    Methodology_human_data_collection
  })
  
  output$Zoonoses_methodology <- renderText({
    Zoonoses_methodology
  })
  
  output$food_prod_methods <- renderText({
    food_prod_methods
  })
  
  output$Vetpath_method <- renderText({
    Vetpath_method
  })
  
  output$AMR_text <- renderText({
    AMR_text_outline
  })
  
  output$AMR_fig_text<- renderText({
    AMR_fig_text_outline
  })
  
  # contributors text outputs ------------------------------------
  output$contributor_report_link <-renderText(
    paste("<a href='", global$Report_website,"'>Find Report and Surveillance Details Here</a>", sep = "")
  )
  
  
  # *** 11. debugging--------------------------------------------------------------------
  
  observeEvent(eventExpr = {
    input$chose_data_type 
  } ,{
    #print(paste("<a href='", global$Report_website,"'>Find Report Here</a>", sep = ""))
    #print(global$high_path)
    #print(global$high_fig_data)
    #print(grepl("E. faecium", global$high_path))
    
    # print(global$resistance_data_human)
    # print(global$resistance_data_cattle)
    # print(global$resistance_data_poultry)
    # # print(global$Data_for_map_not_grouped)
  })
  
  
}



# 12. Run the application -----------------------------------------------------


shinyApp(ui = ui, server = server)
