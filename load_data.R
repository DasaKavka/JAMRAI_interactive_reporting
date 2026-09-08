library(tidyverse)
library(here)
library(datapasta)

# ── Antibiotic abbreviations as they appear in column headers ─────────────────
# Matches "GEN (%)", "AMK (%)", "MDR (%)", or bare "GEN", "AMK", etc.
ANTIBIOTICS <- c(
  "GEN", "AMK", "CHL", "AMP", "CTX", "CAZ", "MEM", "TGC",
  "NAL", "CIP", "AZM", "COL", "SMX", "TMP", "TET", "CS", "MDR"
)
ab_pattern <- paste0("^(", paste(ANTIBIOTICS, collapse = "|"), ")(\\s*\\(%\\))?$")

# ── Read and process a single CSV file ───────────────────────────────────────
# All files are returned; antibiotic columns are pivoted where present.
# Files whose read fails are returned as NULL.
process_csv <- function(path) {
  # Read everything as character to avoid type coercion on mixed-type files
  df <- tryCatch(
    read_csv(
      path,
      col_types     = cols(.default = col_character()),
      locale        = locale(encoding = "UTF-8"),
      show_col_types = FALSE,
      name_repair   = "unique_quiet"
    ),
    error = function(e) NULL
  )

  if (is.null(df) || nrow(df) == 0) return(NULL)

  # Annex D files have a two-row header: the real header is row 1, but a
  # secondary unit row (containing "n", "%", "95% CI" etc.) is read as the
  # first data row. Detect and drop it: the first data row's first column is
  # empty when this occurs.
  first_val <- trimws(as.character(df[[1]][1]))
  if (!is.na(first_val) && first_val == "") {
    df <- df[-1, ]
  }

  # Identify antibiotic columns and combined-resistance columns; pivot if found
  ab_cols    <- names(df)[grepl(ab_pattern, names(df))]
  extra_cols <- names(df)[grepl("Resistance to both", names(df))]
  pivot_cols <- c(ab_cols, extra_cols)

  if (length(pivot_cols) > 0) {
    df <- df |>
      pivot_longer(
        cols      = all_of(pivot_cols),
        names_to  = "Antibiotic",
        values_to = "Resistance_pct"
      ) |>
      mutate(
        Antibiotic     = str_remove(Antibiotic, "\\s*\\(%\\)$"),
        Resistance_pct = suppressWarnings(as.numeric(Resistance_pct))
      )
  }

  df
}

# ── Collect all CSV paths under ../csv_export ─────────────────────────────────
csv_root  <- here("..", "csv_export")
csv_files <- list.files(csv_root, pattern = "\\.csv$", recursive = TRUE,
                        full.names = TRUE)

message("Found ", length(csv_files), " CSV files. Processing...\n")

# ── Load, tag, and combine ────────────────────────────────────────────────────
amr_data <- map(csv_files, function(f) {
  subdir <- basename(dirname(f))
  fname  <- basename(f)

  df <- process_csv(f)

  if (is.null(df)) {
    message("  [fail] ", subdir, "/", fname)
    return(NULL)
  }

  message("  [load] ", subdir, "/", fname, " — ", nrow(df), " rows")

  df |>
    mutate(
      subdir_name = subdir,
      file_name   = fname,
      .before     = 1
    )
}) |>
  compact() |>
  bind_rows()

# ── Summary ───────────────────────────────────────────────────────────────────
message(
  "\nLoaded ", nrow(amr_data), " rows from ",
  n_distinct(amr_data$file_name), " files across ",
  n_distinct(amr_data$subdir_name), " subdirectories."
)

glimpse(amr_data)


# ── cleaning data ───────────────────────────────────────────────────────────────────

amr_data_efsa <- amr_data %>%
  filter(!is.na(Resistance_pct))


# ── Load a single "AMR - 2025 Interactive dashboard_BE_*.csv" file ────────────
# These files are UTF-16 encoded with a two-row header:
#   row 1 — reporting year (repeated per pair of columns)
#   row 2 — "Antimicrobial substance" | "Occurrence of resistance" | "Number of isolates tested"
# Returns a tidy long data frame with columns:
#   animal, antimicrobial, year, occurrence_pct (0-100), n_isolates
load_amr_2025 <- function(path) {
  raw <- read_csv(
    path,
    locale         = locale(encoding = "UTF-16"),
    col_names      = FALSE,
    col_types      = cols(.default = col_character()),
    show_col_types = FALSE
  )

  # Extract animal label from filename (e.g. "broilers", "calves", "fattening pigs")
  animal <- basename(path) |>
    str_extract("(?<=_BE_).+(?=\\.csv$)") |>
    str_replace_all("_", " ")

  # Build one-row column names by forward-filling years across paired columns
  years <- tibble(yr = unlist(raw[1, ])) |>
    mutate(yr = if_else(yr == "Reporting year", NA_character_, yr)) |>
    fill(yr, .direction = "down") |>
    pull(yr)

  metrics   <- unlist(raw[2, ])
  col_names <- if_else(
    metrics == "Antimicrobial substance",
    "antimicrobial",
    paste0(years, "_", metrics)
  )

  # Drop header rows, pivot to long, clean types
  raw[-c(1, 2), ] |>
    setNames(col_names) |>
    filter(!is.na(antimicrobial), trimws(antimicrobial) != "") |>
    pivot_longer(
      cols      = -antimicrobial,
      names_to  = c("year", "metric"),
      names_sep = "_",
      values_to = "value"
    ) |>
    mutate(
      animal = animal,
      year   = as.integer(year),
      value  = as.numeric(str_remove(value, "%"))
    ) |>
    pivot_wider(names_from = metric, values_from = value) |>
    rename(
      occurrence_pct = `Occurrence of resistance`,
      n_isolates     = `Number of isolates tested`
    ) |>
    select(animal, antimicrobial, year, occurrence_pct, n_isolates)
}

# ── Load all three BE dashboard files and combine ────────────────────────────
load_all_amr_2025 <- function(data_dir = here::here("Data")) {
  list.files(data_dir, pattern = "^AMR - 2025.*\\.csv$", full.names = TRUE) |>
    map(load_amr_2025) |>
    bind_rows()
}

# Usage:
# amr_2025 <- load_all_amr_2025()


