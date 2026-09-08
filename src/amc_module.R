# === amc_module.R — reusable AMC chart block (filters + switches + slider + D3) ===
# Lets the AMC tab host any number of independent chart instances: each one
# gets its own filters, own year range, own curve/radar toggle, own D3 output.
# The "Add another chart" button (wired in server.R) inserts more of these at
# runtime — nothing about the number of charts is fixed ahead of time.

amcChartUI <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(4,
             awesomeCheckboxGroup(ns("host_amc"), label = h3("Select Species"),
                                  choices = c("Human", "Animal"),
                                  selected = c("Human"))),
      column(4,
             awesomeCheckboxGroup(ns("region_amc"), label = h3("Select Region"),
                                  choices = c("Belgium", "Europe"),
                                  selected = c("Belgium", "Europe")))
    ),
    
    div(class = "amc-controls",
        fluidRow(
          column(4,
                 materialSwitch(
                   inputId = ns("Zoom_switch_amc1"),
                   label = "Zoom in scale",
                   status = "primary",
                   right = TRUE
                 )),
          column(4,
                 materialSwitch(
                   inputId = ns("amc_chart_type_radar"),
                   label = "Radar chart",
                   status = "primary",
                   right = TRUE
                 ))
        )),
    
    div(class = "amc-year",
        sliderInput(ns("year_amc1"), label = "Select Years", min = 2007,
                    max = 2024, value = c(2007, 2024), sep = "", width = "100%")),
    
    htmlOutput(ns("AMC_fig_text")),
    
    fluidRow(
      box(width = 12, collapsible = TRUE,
          title = NULL,
          d3Output(ns("amc_d3"), height = "820px"))),
  
    htmlOutput(ns("AMC_text")))
  
}

amcChartServer <- function(id, Intersectoral_AMC) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    
    # default palette in R, overridable by clicking a legend swatch in the D3
    # (this instance's own picks — independent from any other chart's)
    DEFAULT_PALETTE <- c("#078BAD", "#0FDBD5", "#1f77b4", "#e4572e", "#2ca02c", "#9467bd", "#8c564b", "#333333")
    user_region_cols <- reactiveValues()
    observeEvent(input$amc_color_pick, {
      pk <- input$amc_color_pick
      if (!is.null(pk$region) && !is.null(pk$color)) user_region_cols[[pk$region]] <- pk$color
    })
    
    # click a legend swatch/label to hide or show that region's curve(s)
    # (independent per chart instance, same on/off pattern as the colour pick)
    user_region_hidden <- reactiveValues()
    observeEvent(input$amc_region_toggle, {
      r <- input$amc_region_toggle
      if (!is.null(r) && nzchar(r)) user_region_hidden[[r]] <- !isTRUE(user_region_hidden[[r]])
    })
    

    amc_fig_data <- reactive({
      d <- Intersectoral_AMC %>%
        filter(Region %in% input$region_amc,
               Host   %in% input$host_amc)
      d
    })
    
    amc_cols <- reactive({
      regs <- sort(unique(as.character(amc_fig_data()$Region)))
      if (length(regs) == 0) return(setNames(character(0), character(0)))
      cols <- setNames(DEFAULT_PALETTE[((seq_along(regs) - 1) %% length(DEFAULT_PALETTE)) + 1], regs)
      for (r in names(cols)) {
        uc <- user_region_cols[[r]]
        if (!is.null(uc) && nzchar(uc)) cols[[r]] <- uc
      }
      cols
    })
    
    output$AMC_text <- renderText({ AMC_text_outline })
    output$AMC_fig_text <- renderText({ AMC_fig_text_outline })
    
    output$amc_d3 <- renderD3({
      d <- amc_fig_data()
      yr <- input$year_amc1
      d <- d[!is.na(d$Year) & d$Year >= min(yr) & d$Year <= max(yr),
             c("Year","icon","signif_level","label_icon","label","Host","mg_kg","Region")]
      mgkg <- suppressWarnings(as.numeric(d$mg_kg))
      ymax <- if (isTRUE(input$Zoom_switch_amc1) && any(!is.na(mgkg)))
        ceiling(max(mgkg, na.rm = TRUE) / 10) * 10 else 175
      cols <- amc_cols()
      hidden_list <- reactiveValuesToList(user_region_hidden)
      hidden_regs <- names(hidden_list)[vapply(hidden_list, isTRUE, logical(1))]
      r2d3::r2d3(
        data = d,
        script = "www/amc_d3.js",   # read server-side by r2d3 (filesystem path, relative to app dir)
        d3_version = "5",
        options = list(
          colors = as.list(cols),
          ymax = ymax,
          chartType = if (isTRUE(input$amc_chart_type_radar)) "radar" else "curve",
          colorPickInputId = ns("amc_color_pick"),
          toggleInputId = ns("amc_region_toggle"),
          hiddenRegions = as.list(hidden_regs)
        )
      )
    })
    # htmlwidgets inside an initially-hidden tab/box can stay blank until the user
    # interacts — compute eagerly so the D3 chart is ready when the tab is shown.
    outputOptions(output, "amc_d3", suspendWhenHidden = FALSE)
  })
}
