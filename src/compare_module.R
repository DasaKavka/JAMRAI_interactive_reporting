# === compare_module.R — unified AMR × AMC comparison tab ===
# One combined view with SHARED controls (region, year, chart type) and AMR-/
# AMC-specific sub-selections. A single D3 output switches between two modes:
#   - "bar"     : dual-axis grouped bars — AMR (left axis, %) + AMC (right axis,
#                 mg/kg), grouped by year, one pair per region. A "Normalise"
#                 switch rescales both series to % of their own max on one axis
#                 so their shapes can be compared directly.
#   - "scatter" : the Monnet plot — x = AMC (mg/kg), y = AMR (%), one point per
#                 (year, region, sector), split into four action zones by the
#                 two medians. Axes auto-fit the data (do NOT start at 0) and
#                 Human vs Animal points use different symbols.
# (Radar lives only on the standalone AMR / AMC tabs, not here.)
# Region palette + D3 primitives are mutualised via src/chart_helpers.R and
# www/chart_common.js.

compareChartUI <- function(id) {
  ns <- NS(id)
  tagList(
    # ---- shared controls (common to AMR & AMC) ----------------------------
    div(class = "cmp-shared",
        fluidRow(
          column(3,
                 awesomeCheckboxGroup(ns("region"), label = h3("Region (shared)"),
                                      choices = c("Belgium", "Europe"),
                                      selected = c("Belgium", "Europe"))),
          column(3,
                 radioButtons(ns("chart_type"), label = h3("Chart type (shared)"),
                              choices = c("Bars — AMR + AMC" = "bar",
                                          "Monnet plot (consumption × resistance)" = "scatter"),
                              selected = "bar"),
                 materialSwitch(ns("normalize"), label = "Normalise to % of max",
                                status = "primary", right = TRUE),
                 materialSwitch(ns("arrows"), label = "Time arrows (Monnet)",
                                status = "primary", right = TRUE, value = TRUE)),
          column(6,
                 div(class = "cmp-year",
                     sliderInput(ns("year"), label = h3("Years (shared)"),
                                 min = 2000, max = 2024, value = c(2000, 2024),
                                 sep = "", width = "100%")))
        )),
    hr(),

    # ---- AMR-/AMC-specific selections -------------------------------------
    fluidRow(
      column(6,
             div(class = "cmp-amr-config",
                 h3("AMR — selection (left axis, %)"),
                 fluidRow(
                   column(6,
                          radioButtons(ns("antibiotic"), label = "Antibiotic",
                                       choices = list("Aminopenicillins" = "Aminopenicillins",
                                                      "Fluoroquinolones" = "Fluoroquinolones",
                                                      "Third-generation cephalosporins" = "Third-generation cephalosporins"),
                                       selected = "Aminopenicillins")),
                   column(6,
                          awesomeCheckboxGroup(ns("host_amr"), label = "Species",
                                               choices = host_species_resistance,
                                               selected = "Human:Blood or CSF"),
                          awesomeCheckboxGroup(ns("bact"), label = "Pathogen",
                                               choices = c("E. coli" = "Escherichia coli"),
                                               selected = "Escherichia coli"))
                 ))),
      column(6,
             div(class = "cmp-amc-config",
                 h3("AMC — selection (right axis, mg/kg)"),
                 awesomeCheckboxGroup(ns("host_amc"), label = "Species",
                                      choices = c("Human", "Animal"),
                                      selected = "Human")))
    ),

    htmlOutput(ns("cmp_caption")),
    fluidRow(
      box(width = 12, collapsible = TRUE, title = NULL,
          d3Output(ns("cmp_chart"), height = "720px"))
    )
  )
}

compareChartServer <- function(id, comparative_AMR_data, Intersectoral_AMC, active_tab = NULL) {
  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    yr_in <- function() {
      yr <- input$year
      if (is.null(yr)) c(2000, 2024) else yr
    }

    # AMR rows for the selection, tagged Human/Animal (sector) and clipped to
    # the shared year range. Keep one value per Year x Region x Sector.
    amr_raw <- reactive({
      comparative_AMR_data %>%
        filter(grepl(paste(input$bact, collapse = "|"), Pathogen),
               Region %in% input$region,
               grepl(input$antibiotic, Antimicrobial),
               grepl(paste(input$host_amr, collapse = "|"), Host)) %>%
        mutate(val = suppressWarnings(as.numeric(Percent_resistant)),
               Sector = if_else(grepl("Human", Host), "Human", "Animal")) %>%
        filter(!is.na(val), !is.na(Year), Year >= min(yr_in()), Year <= max(yr_in()))
    })

    amc_raw <- reactive({
      Intersectoral_AMC %>%
        filter(Region %in% input$region, Host %in% input$host_amc) %>%
        mutate(val = suppressWarnings(as.numeric(mg_kg)),
               Sector = if_else(Host == "Human", "Human", "Animal")) %>%
        filter(!is.na(val), !is.na(Year), Year >= min(yr_in()), Year <= max(yr_in()))
    })

    # bar view: one value per Year x Region (aggregated over sector)
    combined <- reactive({
      amr_bar <- amr_raw() %>% group_by(Year, Region) %>%
        summarise(val = mean(val, na.rm = TRUE), .groups = "drop") %>% mutate(metric = "AMR")
      amc_bar <- amc_raw() %>% group_by(Year, Region) %>%
        summarise(val = mean(val, na.rm = TRUE), .groups = "drop") %>% mutate(metric = "AMC")
      bind_rows(amr_bar, amc_bar)
    })

    # Monnet plot: pair AMR (y) and AMC (x) on Year x Region x Sector, so each
    # point keeps its Human/Animal sector (drawn with a distinct symbol).
    scatter_data <- reactive({
      a <- amr_raw() %>% group_by(Year, Region, Sector) %>%
        summarise(y = mean(val, na.rm = TRUE), .groups = "drop")
      b <- amc_raw() %>% group_by(Year, Region, Sector) %>%
        summarise(x = mean(val, na.rm = TRUE), .groups = "drop")
      if (!nrow(a) || !nrow(b))
        return(data.frame(Year = numeric(), Region = character(), Sector = character(),
                          x = numeric(), y = numeric()))
      inner_join(a, b, by = c("Year", "Region", "Sector")) %>%
        arrange(Region, Sector, Year)
    })

    # shared palette + recolour/hide-region wiring (src/chart_helpers.R)
    state <- region_color_state(input, session, combined,
                                pick = "cmp_color_pick", toggle = "cmp_region_toggle")

    output$cmp_caption <- renderText({
      if (identical(input$chart_type, "scatter")) {
        n <- nrow(scatter_data())
        paste0("<p style='color:#0C5468;margin:2px 0 10px'>",
               "<b>Monnet plot.</b> Each point is one year for a region/sector: ",
               "x = <b>consumption</b> (AMC, mg/kg), y = <b>resistance</b> (AMR, %). ",
               "The two <i>medians</i> split the plane into four action zones. ",
               "Circles = human, triangles = animal. Axes auto-fit the data. ",
               "<b>", n, "</b> matched point(s) for the current selection.",
               "</p>")
      } else {
        paste0("<p style='color:#0C5468;margin:2px 0 10px'>",
               "AMR (resistance, %) and AMC (consumption, mg/kg) on a shared basis ",
               "(region, years). Solid bars = <b>AMR</b> (left axis) · ",
               "hatched bars = <b>AMC</b> (right axis). ",
               "Toggle <i>Normalise</i> to compare their shapes on a single 0–100 % axis.",
               "</p>")
      }
    })

    output$cmp_chart <- renderD3({
      # depend on the active tab so opening the AMR/AMC tab re-runs this render
      # with the container visible (avoids a deferred/blank first render)
      if (!is.null(active_tab)) active_tab()
      type <- input$chart_type %||% "bar"

      if (identical(type, "scatter")) {
        d <- scatter_data()
        cols <- if (nrow(d)) region_palette(d$Region) else list()
        r2d3::r2d3(
          data = d[, c("Year", "Region", "Sector", "x", "y")],
          script = "www/compare_d3.js",
          d3_version = "5",
          options = list(
            mode = "scatter",
            arrows = isTRUE(input$arrows),
            colors = as.list(cols),
            xmed = if (nrow(d)) median(d$x, na.rm = TRUE) else 0,
            ymed = if (nrow(d)) median(d$y, na.rm = TRUE) else 0,
            xlab = "Antibiotic consumption (AMC, mg/kg)",
            ylab = "Resistance level (AMR, %)"
          )
        )
      } else {
        d <- combined()
        cols <- if (nrow(d)) region_palette(d$Region) else list()
        amr_pr <- suppressWarnings(as.numeric(amr_raw()$val))
        amc_pr <- suppressWarnings(as.numeric(amc_raw()$val))
        r2d3::r2d3(
          data = d[, c("Year", "Region", "metric", "val")],
          script = "www/compare_d3.js",
          d3_version = "5",
          options = list(
            mode = "bar",
            normalize = isTRUE(input$normalize),
            colors = as.list(cols),
            amrMax = if (length(amr_pr) && any(!is.na(amr_pr))) max(100, ceiling(max(amr_pr, na.rm = TRUE) / 10) * 10) else 100,
            amcMax = if (length(amc_pr) && any(!is.na(amc_pr))) ceiling(max(amc_pr, na.rm = TRUE) / 10) * 10 else 175,
            colorPickInputId = ns("cmp_color_pick"),
            toggleInputId = ns("cmp_region_toggle"),
            hiddenRegions = as.list(state$hidden())
          )
        )
      }
    })
    outputOptions(output, "cmp_chart", suspendWhenHidden = FALSE)
  })
}
