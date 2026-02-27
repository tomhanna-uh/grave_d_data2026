# =============================================================================
# 03_build_grave_d_ideology.R
# Merge GRAVE-D leadership ideology and support group variables
#
# Input:  output/spine_conflict.rds     (from 02_build_conflict.R)
#         source_data/grave_d/          (GRAVE-D coding files)
# Output: output/spine_ideology.rds
#
# GRAVE-D Variables merged:
#
# Leadership Ideology (Side A):
#   sidea_revisionist_domestic
#   sidea_nationalist_revisionist_domestic
#   sidea_socialist_revisionist_domestic
#   sidea_religious_revisionist_domestic
#   sidea_reactionary_revisionist_domestic
#   sidea_separatist_revisionist_domestic
#   sidea_dynamic_leader
#
# Support Groups (Side A):
#   sidea_religious_support
#   sidea_party_elite_support
#   sidea_rural_worker_support
#   sidea_military_support
#   sidea_ethnic_racial_support
#   sidea_winning_coalition_size
# =============================================================================

source(here::here("R", "00_packages.R"))

message("[03_build_grave_d_ideology.R] Starting GRAVE-D ideology merge...")

# -----------------------------------------------------------------------------
# 1. Load spine with conflict
# -----------------------------------------------------------------------------
spine_path <- here("output", "spine_conflict.rds")
if (!file.exists(spine_path)) {
  stop(
    "[03] spine_conflict.rds not found.\n",
    "  Run R/02_build_conflict.R first."
  )
}
spine <- readRDS(spine_path)
message(sprintf("[03] Loaded spine: %d rows", nrow(spine)))

# -----------------------------------------------------------------------------
# 2. Load GRAVE-D coding file
# -----------------------------------------------------------------------------
# Expected: source_data/grave_d/GRAVE_D_coding.csv
# This file contains country-year leader ideology and support group coding.
# Merge key: COWcode (country), year

grave_files <- list.files(
  here("source_data", "grave_d"),
  pattern = ".*\\.csv$|.*\\.dta$|.*\\.xlsx$",
  full.names = TRUE
)

if (length(grave_files) == 0) {
  stop(
    "[03] No GRAVE-D source files found in source_data/grave_d/\n",
    "  Place GRAVE-D coding CSV or Stata file in that directory."
  )
}

if (length(grave_files) > 1) {
  stop(
    "[03] Multiple GRAVE-D source files found in source_data/grave_d/: ",
    paste(basename(grave_files), collapse = ", "),
    "\n  Please ensure only one coding file is present to avoid ambiguity."
  )
}

message(sprintf("[03] Found GRAVE-D file: %s", grave_files[1]))

if (grepl("\\.csv$", grave_files[1])) {
  grave_raw <- as_tibble(data.table::fread(file = grave_files[1]))
} else if (grepl("\\.dta$", grave_files[1])) {
  grave_raw <- haven::read_dta(grave_files[1])
} else {
  grave_raw <- readxl::read_excel(grave_files[1])
}

message(sprintf("[03] GRAVE-D raw: %d rows x %d cols", nrow(grave_raw), ncol(grave_raw)))

# -----------------------------------------------------------------------------
# 3. Standardize column names
# -----------------------------------------------------------------------------
grave_raw <- grave_raw |>
  rename_with(tolower)

# Standardize COW code column name
if ("cowcode" %in% names(grave_raw)) {
  grave_raw <- grave_raw |> rename(COWcode = cowcode)
} else if ("ccode" %in% names(grave_raw)) {
  grave_raw <- grave_raw |> rename(COWcode = ccode)
}

# -----------------------------------------------------------------------------
# 4. Define GRAVE-D columns to merge
# -----------------------------------------------------------------------------
grave_ideology_cols <- c(
  "COWcode", "year",
  # Composite revisionist ideology
  "sidea_revisionist_domestic",
  # By ideology type
  "sidea_nationalist_revisionist_domestic",
  "sidea_socialist_revisionist_domestic",
  "sidea_religious_revisionist_domestic",
  "sidea_reactionary_revisionist_domestic",
  "sidea_separatist_revisionist_domestic",
  # Dynamic leadership
  "sidea_dynamic_leader",
  # Support groups
  "sidea_religious_support",
  "sidea_party_elite_support",
  "sidea_rural_worker_support",
  "sidea_military_support",
  "sidea_ethnic_racial_support",
  "sidea_winning_coalition_size"
)

# Select available columns (warn on missing)
present_cols <- intersect(grave_ideology_cols, names(grave_raw))
missing_cols <- setdiff(grave_ideology_cols[-c(1,2)], names(grave_raw)) # exclude key cols

if (length(missing_cols) > 0) {
  warning(
    "[03] These GRAVE-D columns not found (will be NA): ",
    paste(missing_cols, collapse = ", ")
  )
}

grave_clean <- grave_raw |>
  select(all_of(present_cols)) |>
  distinct(COWcode, year, .keep_all = TRUE)

message(sprintf("[03] GRAVE-D clean: %d country-year rows", nrow(grave_clean)))

# -----------------------------------------------------------------------------
# 5. Merge onto spine (Side A: COWcode_a)
# -----------------------------------------------------------------------------
spine_ideology <- spine |>
  left_join(
    grave_clean |> rename_with(~ paste0("sidea_", .), .cols = -c(COWcode, year)) |>
      # If columns already have sidea_ prefix, avoid double-prefixing
      rename(COWcode_a = COWcode),
    by = c("COWcode_a", "year")
  )

# Report merge coverage for key ideology variable
if ("sidea_revisionist_domestic" %in% names(spine_ideology)) {
  n_matched <- sum(!is.na(spine_ideology$sidea_revisionist_domestic))
  message(sprintf(
    "[03] sidea_revisionist_domestic: %d rows matched (%.1f%%)",
    n_matched, 100 * n_matched / nrow(spine_ideology)
  ))
}

# -----------------------------------------------------------------------------
# 6. Save
# -----------------------------------------------------------------------------
saveRDS(spine_ideology, here("output", "spine_ideology.rds"))
message("[03_build_grave_d_ideology.R] Saved: output/spine_ideology.rds")
message("[03_build_grave_d_ideology.R] Done.")
