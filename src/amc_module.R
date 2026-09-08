# === amc_module.R — reusable AMC chart block (filters + switches + slider + D3) ===
# Lets the AMC tab host any number of independent chart instances: each one
# gets its own filters, own year range, own curve/radar toggle, own D3 output.
#
# Palette + "recolour/hide a region from the legend" behaviour are shared with
# the AMR and comparison modules via src/chart_helpers.R (region_color_state).
# amcChartServer() RETURNS its year-clipped filtered data (+ selected years) so
# the AMR/AMC comparison tab can pair it with the AMR series.

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

    amc_fig_data <- reactive({
      d <- Intersectoral_AMC %>%
        filter(Region %in% input$region_amc,
               Host   %in% input$host_amc)
      d
    })

    # exact rows drawn by the D3 chart (year-clipped) — also consumed by the
    # AMR/AMC comparison tab for the quadrant scatter
    amc_plot_data <- reactive({
      d <- amc_fig_data()
      yr <- input$year_amc1
      d[!is.na(d$Year) & d$Year >= min(yr) & d$Year <= max(yr),
        c("Year", "icon", "signif_level", "label_icon", "label", "Host", "mg_kg", "Region")]
    })

    # shared palette + recolour/hide-region wiring (src/chart_helpers.R)
    state <- region_color_state(input, session, amc_fig_data,
                                pick = "amc_color_pick", toggle = "amc_region_toggle")

    output$AMC_text <- renderText({ AMC_text_outline })
    output$AMC_fig_text <- renderText({ AMC_fig_text_outline })

    output$amc_d3 <- renderD3({
      d <- amc_plot_data()
      mgkg <- suppressWarnings(as.numeric(d$mg_kg))
      ymax <- if (isTRUE(input$Zoom_switch_amc1) && any(!is.na(mgkg)))
        ceiling(max(mgkg, na.rm = TRUE) / 10) * 10 else 175
      r2d3::r2d3(
        data = d,
        script = "www/amc_d3.js",   # read server-side by r2d3 (filesystem path, relative to app dir)
        d3_version = "5",
        options = list(
          colors = as.list(state$cols()),
          ymax = ymax,
          chartType = if (isTRUE(input$amc_chart_type_radar)) "radar" else "curve",
          colorPickInputId = ns("amc_color_pick"),
          toggleInputId = ns("amc_region_toggle"),
          hiddenRegions = as.list(state$hidden())
        )
      )
    })
    # htmlwidgets inside an initially-hidden tab/box can stay blank until the user
    # interacts — compute eagerly so the D3 chart is ready when the tab is shown.
    outputOptions(output, "amc_d3", suspendWhenHidden = FALSE)

    # exposed to the AMR/AMC comparison tab (src/compare_module.R)
    list(
      data = amc_plot_data,
      years = reactive(input$year_amc1)
    )
  })
}
