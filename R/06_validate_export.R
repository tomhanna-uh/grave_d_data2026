# -------------------------------------------------------------------------
# 06_validate_export.R
# Validate the GRAVE-D master dataset and export final versions
# -------------------------------------------------------------------------

source(here::here("R", "00_packages.R"))
message("[06_validate_export.R] Validating GRAVE-D master dataset...")

# -------------------------------------------------------------------------
# 1. LOAD MASTER DATA
# -------------------------------------------------------------------------

grave_d_path <- here("output", "GRAVE_D_Master.rds")
if (!file.exists(grave_d_path)) {
  cli::cli_abort("Master dataset not found at {.path {grave_d_path}}. Run R/05_build_master.R first.")
}
grave_d <- readRDS(grave_d_path)
message("  Loaded: GRAVE_D_Master (", nrow(grave_d), " rows)")

# -------------------------------------------------------------------------
# 2. VALIDATION CHECKS
# -------------------------------------------------------------------------

cli::cli_h2("Running Validation Checks")

# Check 1: Non-empty
if (nrow(grave_d) == 0) {
  cli::cli_abort("Dataset is empty.")
}
cli::cli_alert_success("Dataset is not empty.")

# Check 2: Primary Key Uniqueness
# Keys: COWcode_a, COWcode_b, year
duplicates <- grave_d |>
  dplyr::group_by(COWcode_a, COWcode_b, year) |>
  dplyr::filter(dplyr::n() > 1)

if (nrow(duplicates) > 0) {
  cli::cli_abort("Duplicate primary keys found for {nrow(duplicates)} dyad-years.")
}
cli::cli_alert_success("Primary keys (COWcode_a, COWcode_b, year) are unique.")

# Check 3: Missing Keys
missing_keys <- grave_d |>
  dplyr::filter(is.na(COWcode_a) | is.na(COWcode_b) | is.na(year))

if (nrow(missing_keys) > 0) {
  cli::cli_abort("Missing values found in primary key columns for {nrow(missing_keys)} rows.")
}
cli::cli_alert_success("No missing values in primary key columns.")

# Check 4: Year Range
year_min <- 1946
year_max <- 2020
invalid_years <- grave_d |>
  dplyr::filter(year < year_min | year > year_max)

if (nrow(invalid_years) > 0) {
  cli::cli_abort("Years outside range {year_min}-{year_max} found: {unique(invalid_years$year)}.")
}
cli::cli_alert_success("All years are within {year_min}-{year_max}.")

# Check 5: Binary Variable Consistency (mid_initiated)
if ("mid_initiated" %in% names(grave_d)) {
  invalid_mid <- grave_d |>
    dplyr::filter(!mid_initiated %in% c(0, 1) & !is.na(mid_initiated))

  if (nrow(invalid_mid) > 0) {
    cli::cli_abort("Invalid values found in 'mid_initiated'. Expected 0 or 1.")
  }
  cli::cli_alert_success("'mid_initiated' contains only 0 or 1.")
} else {
  cli::cli_alert_warning("'mid_initiated' column missing from dataset.")
}

# -------------------------------------------------------------------------
# 3. EXPORT FINAL DATASETS
# -------------------------------------------------------------------------

cli::cli_h2("Exporting to ready_data/")

# Create ready_data directory if not exists
if (!dir.exists(here("ready_data"))) {
  dir.create(here("ready_data"))
}

# Export 1: GRAVE_D_Master.csv
readr::write_csv(grave_d, here("ready_data", "GRAVE_D_Master.csv"))
cli::cli_alert_success("Exported: {.path ready_data/GRAVE_D_Master.csv}")

# Export 2: GRAVE_D_Master_with_Leaders.csv
# (Same content, just explicit naming as per README)
readr::write_csv(grave_d, here("ready_data", "GRAVE_D_Master_with_Leaders.csv"))
cli::cli_alert_success("Exported: {.path ready_data/GRAVE_D_Master_with_Leaders.csv}")

message("[06_validate_export.R] Done.")
