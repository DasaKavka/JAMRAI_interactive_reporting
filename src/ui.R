# === ui.R — UI (header, sidebar, tabs); defines `ui` ===
# Page-level JS lives in www/app.js.

# 4b. Define UI sidebar --------------------------------------------------------------
sidebar <- dashboardSidebar(
  
  tagList(
    tags$head(
      tags$link(rel = "stylesheet", type="text/css", href="style2_2.css"))),
  
  sidebarMenu(id= "sbmenu",
              menuItem("Welcome", tabName = "Welcome", icon = icon("door-open", lib = "font-awesome", tabName = "Welcome")),
              menuItem("Methodology", tabName = "Methodology", icon = icon("calculator", lib = "font-awesome", tabName = "Methodology")),
              menuItem("AMR", icon = icon("bacteria", lib = "font-awesome"), tabName = "AMR"),
              menuItem("AMC", icon = icon("pills", lib = "font-awesome"), tabName = "AMC"),
              menuItem("Contributors", icon = icon("server", lib = "font-awesome"), tabName = "contributors")
  )
)

body <- dashboardBody(
  tags$script(src = "app.js"),   # page-level JS: loading-logo swap + header subtitle (rendered once)
 # tags$head(includeHTML("google-analytics.html")), # update if want to include google analytics for your report
  # CSS (style2_2.css) is loaded via the header/sidebar tags$head
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
              div(id = "amr_chart_block_chart1", class = "amr-chart-block",
                  amrChartUI("chart1"))
            )),
    
    
    # AMC Tab layout -----------------------------------------------
    tabItem(tabName = "AMC",
            fluidPage(
              div(id = "amc_chart_block_chart2", class = "amc-chart-block",
                  amcChartUI("chart2"))
            )),
    
    
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
  title = "JAMRAI2 Dashboard",  # browser tab title — kept plain text on purpose;
                                 # dashboardHeader's title below is a rich <a> tag,
                                 # and without this dashboardPage falls back to
                                 # deparsing that tag into the tab title.
  # freshTheme = theme,
  #  tags$script(src = "https://kit.fontawesome.com/7d2f617ce8.js"),

  #5a. UI Header -------------------------------------------------------------
  # skin = "green",
  dashboardHeader(title = tags$a(href = 'https://eu-jamrai.eu/', "JAMRAI2 Dashboard")),
  sidebar,
  body
)
