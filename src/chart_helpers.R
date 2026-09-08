# === chart_helpers.R — helpers shared across the AMR / AMC / comparison modules ===
# Previously each module (amr_module.R, amc_module.R) redefined its own palette
# plus the whole "click a legend swatch to recolour / hide a region" machinery.
# The new AMR/AMC tab would have made a 3rd copy of it. All this common code now
# lives here and is called identically by the 3 modules.

# A single palette for every chart (regions coloured by index, unless the user
# explicitly overrides via the legend picker).
DEFAULT_PALETTE <- c("#078BAD", "#0FDBD5", "#1f77b4", "#e4572e",
                     "#2ca02c", "#9467bd", "#8c564b", "#333333")

# Builds a named vector region -> colour, applying the overrides chosen by the
# user (user_cols: a reactiveValues region -> hex).
region_palette <- function(regs, user_cols = NULL) {
  regs <- sort(unique(as.character(regs)))
  if (length(regs) == 0) return(setNames(character(0), character(0)))
  cols <- setNames(DEFAULT_PALETTE[((seq_along(regs) - 1) %% length(DEFAULT_PALETTE)) + 1], regs)
  if (!is.null(user_cols)) for (r in names(cols)) {
    uc <- user_cols[[r]]
    if (!is.null(uc) && nzchar(uc)) cols[[r]] <- uc
  }
  cols
}

# Wires the shared "recolour / hide a region from the D3 legend" behaviour.
# Returns two reactives: the current colour table and the list of hidden
# regions — to be passed as-is to the r2d3 options.
#   input, session : those of the calling moduleServer
#   fig_data       : reactive returning the module's filtered data.frame (Region col)
#   pick, toggle   : *local* (non-namespaced) input names written by the JS
#                    via session$ns(...); they differ between AMR and AMC.
region_color_state <- function(input, session, fig_data,
                               pick = "color_pick", toggle = "region_toggle") {
  user_cols <- reactiveValues()
  observeEvent(input[[pick]], {
    pk <- input[[pick]]
    if (!is.null(pk$region) && !is.null(pk$color)) user_cols[[pk$region]] <- pk$color
  })

  user_hidden <- reactiveValues()
  observeEvent(input[[toggle]], {
    r <- input[[toggle]]
    if (!is.null(r) && nzchar(r)) user_hidden[[r]] <- !isTRUE(user_hidden[[r]])
  })

  list(
    cols = reactive(region_palette(fig_data()$Region, user_cols)),
    hidden = reactive({
      hl <- reactiveValuesToList(user_hidden)
      names(hl)[vapply(hl, isTRUE, logical(1))]
    })
  )
}
