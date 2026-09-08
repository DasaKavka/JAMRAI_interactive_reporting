# === amr_module.R — reusable AMR chart block (filters + switches + slider + D3) ===
# Lets the AMR tab host any number of independent chart instances: each one
# gets its own filters, own year range, own curve/radar toggle, own D3 output.
# The "Add another chart" button (wired in server.R) inserts more of these at
# runtime — nothing about the number of charts is fixed ahead of time.
#
# Palette + "recolour/hide a region from the legend" behaviour are shared with
# the AMC and comparison modules via src/chart_helpers.R (region_color_state).
# amrChartServer() RETURNS its year-clipped filtered data (+ selected years) so
# the AMR/AMC comparison tab can pair it with the AMC series (no duplicated
# filtering).

amrChartUI <- function(id) {
  ns <- NS(id)
  tagList(
    fluidRow(
      column(4,
             radioButtons(ns("antibiotic"), label = h3("Select Antibiotic"),
                          choices = list("Aminopenicillins" = "Aminopenicillins",
                                         "Fluoroquinolones" = "Fluoroquinolones",
                                         "Third-generation cephalosporins" = "Third-generation cephalosporins"),
                          selected = c("Aminopenicillins"))),
      column(4,
             awesomeCheckboxGroup(ns("host"), label = h3("Select Species"),
                                  choices = host_species_resistance,
                                  selected = c("Human:Blood or CSF"))),
      column(4,
             awesomeCheckboxGroup(ns("bact"), label = h3("Select Pathogen"),
                                  choices = c("E. coli" = "Escherichia coli"),
                                  selected = c("Escherichia coli"))),
      column(4,
             awesomeCheckboxGroup(ns("region"), label = h3("Select Region"),
                                  choices = c("Belgium", "Europe"),
                                  selected = c("Belgium", "Europe")))
    ),

    div(class = "amr-controls",
        fluidRow(
          column(4,
                 materialSwitch(
                   inputId = ns("amr_ss1"),
                   label = "Show Belgian sample sizes",
                   status = "primary",
                   right = TRUE
                 )),
          column(4,
                 materialSwitch(
                   inputId = ns("Zoom_switch_amr1"),
                   label = "Zoom in scale",
                   status = "primary",
                   right = TRUE
                 )),
          column(4,
                 materialSwitch(
                   inputId = ns("amr_chart_type_radar"),
                   label = "Radar chart",
                   status = "primary",
                   right = TRUE
                 ))
        )),

    div(class = "amr-year",
        sliderInput(ns("year_amr1"), label = "Select Years", min = 2000,
                    max = 2024, value = c(2000, 2024), sep = "", width = "100%")),

    htmlOutput(ns("AMR_fig_text")),


    fluidRow(
      box(width = 12, collapsible = TRUE,
          title = NULL,
          d3Output(ns("amr_d3"), height = "820px"))
    ),
    htmlOutput(ns("AMR_text"))
  )
}

amrChartServer <- function(id, comparative_AMR_data) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    # rows matching this instance's filters (species / region / antibiotic / host)
    amr_fig_data <- reactive({
      d <- comparative_AMR_data %>%
        filter(grepl(paste(input$bact, collapse = "|"), Pathogen),
               grepl(paste(input$region, collapse = "|"), Region),
               grepl(input$antibiotic, Antimicrobial),
               grepl(paste(input$host, collapse = "|"), Host))
      if (isTRUE(input$amr_ss1)) {
        d <- d %>% mutate(Sample_size = if_else(grepl("Belgium", Region), as.character(Sample_size.x), ""))
      } else {
        d <- d %>% mutate(Sample_size = "")
      }
      d
    })

    # the same rows clipped to the selected year range — the exact data drawn by
    # the D3 chart, and what the comparison tab consumes for the quadrant scatter
    amr_plot_data <- reactive({
      d <- amr_fig_data()
      if (!"Sample_size.x" %in% names(d)) d$Sample_size.x <- NA
      yr <- input$year_amr1
      d <- d[!is.na(d$Year) & d$Year >= min(yr) & d$Year <= max(yr),
             c("Year", "Region", "Host", "Percent_resistant",
               "Percent_resistant_predict", "CI_lower", "CI_upper", "Sample_size.x")]
      names(d)[names(d) == "Sample_size.x"] <- "Sample_size"
      d
    })

    # shared palette + recolour/hide-region wiring (src/chart_helpers.R)
    state <- region_color_state(input, session, amr_fig_data,
                                pick = "amr_color_pick", toggle = "amr_region_toggle")

    # click the "GLM trend" legend entry to hide/show the forecast (dashed
    # line + CI ribbon) for every region at once — AMR-specific, separate from
    # the per-region toggle handled by region_color_state above.
    trend_hidden <- reactiveVal(FALSE)
    observeEvent(input$amr_trend_toggle, {
      trend_hidden(!trend_hidden())
    })

    output$AMR_text <- renderText({ AMR_text_outline })
    output$AMR_fig_text <- renderText({ AMR_fig_text_outline })

    output$amr_d3 <- renderD3({
      d <- amr_plot_data()
      pr <- suppressWarnings(as.numeric(d$Percent_resistant))
      ymax <- if (isTRUE(input$Zoom_switch_amr1) && any(!is.na(pr)))
        ceiling(max(pr, na.rm = TRUE) / 10) * 10 else 100
      r2d3::r2d3(
        data = d,
        script = "www/amr_d3.js",   # read server-side by r2d3 (filesystem path, relative to app dir)
        d3_version = "5",
        options = list(
          colors = as.list(state$cols()),
          ymax = ymax,
          showSampleSizes = isTRUE(input$amr_ss1),
          chartType = if (isTRUE(input$amr_chart_type_radar)) "radar" else "curve",
          colorPickInputId = ns("amr_color_pick"),
          toggleInputId = ns("amr_region_toggle"),
          hiddenRegions = as.list(state$hidden()),
          trendToggleInputId = ns("amr_trend_toggle"),
          trendHidden = isTRUE(trend_hidden())
        )
      )
    })
    # htmlwidgets inside an initially-hidden tab/box can stay blank until the user
    # interacts — compute eagerly so the D3 chart is ready when the tab is shown.
    outputOptions(output, "amr_d3", suspendWhenHidden = FALSE)

    # exposed to the AMR/AMC comparison tab (src/compare_module.R)
    list(
      data = amr_plot_data,
      years = reactive(input$year_amr1)
    )
  })
}
