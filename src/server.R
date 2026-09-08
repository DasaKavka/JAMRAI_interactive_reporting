# === server.R — server logic; defines `server` ===

server <- function(input, output, session) {
  # 6A. Define reactive values and data ----------------------------------------------------------
  # ***define global ---------------------------------------------------------------
  global <- reactiveValues(

    # define contributors reactive
    chose_analysis_type = "Human- E. coli",
    Contributor = "Sciensano",
    Report = "EARS-be and NSIH-AMR",
    Report_website  = "https://www.sciensano.be/en/about-sciensano/sciensanos-organogram/healthcare-associated-infections-and-antimicrobial-resistance"

  )


  # 6A.2 AMR chart — a self-contained amrChartServer/amrChartUI instance
  # (src/amr_module.R): its own filters, own reactive filtering, own D3 output.
  amrChartServer("chart1", comparative_AMR_data)

  # 6A.2 AMC chart — a self-contained amcChartServer/amcChartUI instanceamc
  amcChartServer("chart2", Intersectoral_AMC)


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
