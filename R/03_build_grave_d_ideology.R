# =============================================================================
# 03_build_grave_d_ideology.R
# Build GRAVE-D leadership ideology and support group variables from
# component sources: Archigos, Colgan leaders, Global Leader Ideology
#
# Input:  data/spine_conflict.rds       (from 02_build_conflict.R)
#         source_data/archigos/          (Archigos leader data)
#         source_data/colgan/            (Colgan leader-level data)
#         source_data/leader_ideology/   (Global Leader Ideology dataset)
# Output: data/spine_ideology.rds
#
# GRAVE-D Variables built:
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

message("[03_build_grave_d_ideology.R] Starting GRAVE-D ideology build...")

# -----------------------------------------------------------------------------
# 1. Load spine with conflict
# -----------------------------------------------------------------------------
spine_path <- here("data", "spine_conflict.rds")
if (!file.exists(spine_path)) {
  stop(
    "[03] spine_conflict.rds not found.\n",
    "  Run R/02_build_conflict.R first."
  )
}
spine <- readRDS(spine_path)
message(sprintf("[03] Loaded spine: %d rows", nrow(spine)))

# -----------------------------------------------------------------------------
# 2. Load Archigos leader data
# -----------------------------------------------------------------------------
# Archigos provides leader IDs, tenure dates, and basic attributes.
# Expected in source_data/archigos/ as .dta, .csv, or .xlsx

archigos_files <- list.files(
  here("source_data", "archigos"),
  pattern = ".*\\.(csv|dta|xlsx)$",
  full.names = TRUE, ignore.case = TRUE
)

if (length(archigos_files) == 0) {
  warning("[03] No Archigos files found in source_data/archigos/. Leader IDs will be absent.")
  archigos_raw <- NULL
} else {
  message(sprintf("[03] Found Archigos file: %s", archigos_files[1]))
  if (grepl("\\.csv$", archigos_files[1], ignore.case = TRUE)) {
    archigos_raw <- as_tibble(data.table::fread(file = archigos_files[1]))
  } else if (grepl("\\.dta$", archigos_files[1], ignore.case = TRUE)) {
    archigos_raw <- haven::read_dta(archigos_files[1])
  } else {
    archigos_raw <- readxl::read_excel(archigos_files[1])
  }
  archigos_raw <- archigos_raw |> rename_with(tolower)
  message(sprintf("[03] Archigos raw: %d rows x %d cols", nrow(archigos_raw), ncol(archigos_raw)))
}

# -----------------------------------------------------------------------------
# 3. Load Colgan leader data
# -----------------------------------------------------------------------------
# Colgan provides leader-level coding (e.g., revolutionary leaders, traits).
# Expected in source_data/colgan/ as .dta or .csv

colgan_files <- list.files(
  here("source_data", "colgan"),
  pattern = ".*\\.(csv|dta|xlsx)$",
  full.names = TRUE, ignore.case = TRUE
)

if (length(colgan_files) == 0) {
  warning("[03] No Colgan files found in source_data/colgan/. Leader traits will be absent.")
  colgan_raw <- NULL
} else {
  message(sprintf("[03] Found Colgan file: %s", colgan_files[1]))
  if (grepl("\\.csv$", colgan_files[1], ignore.case = TRUE)) {
    colgan_raw <- as_tibble(data.table::fread(file = colgan_files[1]))
  } else if (grepl("\\.dta$", colgan_files[1], ignore.case = TRUE)) {
    colgan_raw <- haven::read_dta(colgan_files[1])
  } else {
    colgan_raw <- readxl::read_excel(colgan_files[1])
  }
  colgan_raw <- colgan_raw |> rename_with(tolower)
  message(sprintf("[03] Colgan raw: %d rows x %d cols", nrow(colgan_raw), ncol(colgan_raw)))
}

# -----------------------------------------------------------------------------
# 4. Load Global Leader Ideology dataset
# -----------------------------------------------------------------------------
# Provides ideological positions/categories for leaders.
# Expected in source_data/leader_ideology/ as .csv, .dta, or .xlsx

ideology_files <- list.files(
  here("source_data", "leader_ideology"),
  pattern = ".*\\.(csv|dta|xlsx)$",
  full.names = TRUE, ignore.case = TRUE
)

if (length(ideology_files) == 0) {
  warning("[03] No leader ideology files found in source_data/leader_ideology/. Ideology scores will be absent.")
  ideology_raw <- NULL
} else {
  message(sprintf("[03] Found leader ideology file: %s", ideology_files[1]))
  if (grepl("\\.csv$", ideology_files[1], ignore.case = TRUE)) {
    ideology_raw <- as_tibble(data.table::fread(file = ideology_files[1]))
  } else if (grepl("\\.dta$", ideology_files[1], ignore.case = TRUE)) {
    ideology_raw <- haven::read_dta(ideology_files[1])
  } else {
    ideology_raw <- readxl::read_excel(ideology_files[1])
  }
  ideology_raw <- ideology_raw |> rename_with(tolower)
  message(sprintf("[03] Leader ideology raw: %d rows x %d cols", nrow(ideology_raw), ncol(ideology_raw)))
}

# -----------------------------------------------------------------------------
# 5. Standardize COW code columns across sources
# -----------------------------------------------------------------------------
standardize_cowcode <- function(df) {
  if (is.null(df)) return(NULL)
  if ("cowcode" %in% names(df)) {
    df <- df |> rename(COWcode = cowcode)
  } else if ("ccode" %in% names(df)) {
    df <- df |> rename(COWcode = ccode)
  }
  df
}

archigos_raw <- standardize_cowcode(archigos_raw)
colgan_raw   <- standardize_cowcode(colgan_raw)
ideology_raw <- standardize_cowcode(ideology_raw)

# -----------------------------------------------------------------------------
# 6. Build leader-year panel from Archigos + Colgan + Ideology
# -----------------------------------------------------------------------------
# TODO: The exact merge logic here depends on your specific variable names
# and matching keys across the three datasets. The structure below provides
# the scaffolding; adjust column names to match your actual source files.
#
# General approach:
#   a) Start from Archigos (leader-year panel with COWcode and year)
#   b) Left-join Colgan leader traits onto Archigos leaders
#   c) Left-join ideology scores onto the result
#   d) Collapse to country-year if needed for dyadic merge

# Define target GRAVE-D ideology columns
grave_ideology_cols <- c(
  "sidea_revisionist_domestic",
  "sidea_nationalist_revisionist_domestic",
  "sidea_socialist_revisionist_domestic",
  "sidea_religious_revisionist_domestic",
  "sidea_reactionary_revisionist_domestic",
  "sidea_separatist_revisionist_domestic",
  "sidea_dynamic_leader",
  "sidea_religious_support",
  "sidea_party_elite_support",
  "sidea_rural_worker_support",
  "sidea_military_support",
  "sidea_ethnic_racial_support",
  "sidea_winning_coalition_size"
)

# Placeholder: build leader_data from available sources
# This section should be customized based on exact column names in your
# Archigos, Colgan, and leader_ideology files.
leader_data <- NULL

if (!is.null(archigos_raw) && "COWcode" %in% names(archigos_raw) && "year" %in% names(archigos_raw)) {
  leader_data <- archigos_raw |>
    select(COWcode, year, everything()) |>
    distinct(COWcode, year, .keep_all = TRUE)
  message(sprintf("[03] Archigos base: %d country-year rows", nrow(leader_data)))
}

if (!is.null(colgan_raw) && !is.null(leader_data)) {
  colgan_join_cols <- intersect(c("COWcode", "year"), names(colgan_raw))
  if (length(colgan_join_cols) == 2) {
    colgan_clean <- colgan_raw |> distinct(COWcode, year, .keep_all = TRUE)
    leader_data <- leader_data |>
      left_join(colgan_clean, by = c("COWcode", "year"), suffix = c("", "_colgan"))
    message(sprintf("[03] After Colgan merge: %d rows", nrow(leader_data)))
  }
} else if (!is.null(colgan_raw) && is.null(leader_data)) {
  leader_data <- colgan_raw |> distinct(COWcode, year, .keep_all = TRUE)
}

if (!is.null(ideology_raw) && !is.null(leader_data)) {
  ideology_join_cols <- intersect(c("COWcode", "year"), names(ideology_raw))
  if (length(ideology_join_cols) == 2) {
    ideology_clean <- ideology_raw |> distinct(COWcode, year, .keep_all = TRUE)
    leader_data <- leader_data |>
      left_join(ideology_clean, by = c("COWcode", "year"), suffix = c("", "_ideo"))
    message(sprintf("[03] After ideology merge: %d rows", nrow(leader_data)))
  }
} else if (!is.null(ideology_raw) && is.null(leader_data)) {
  leader_data <- ideology_raw |> distinct(COWcode, year, .keep_all = TRUE)
}

# -----------------------------------------------------------------------------
# 7. Merge leader data onto spine (Side A: COWcode_a)
# -----------------------------------------------------------------------------
if (!is.null(leader_data)) {
  # Check which target ideology columns are present
  present_cols <- intersect(grave_ideology_cols, names(leader_data))
  missing_cols <- setdiff(grave_ideology_cols, names(leader_data))

  if (length(missing_cols) > 0) {
    warning(
      "[03] These GRAVE-D ideology columns not found in merged leader data (will be NA): ",
      paste(missing_cols, collapse = ", ")
    )
  }

  # Select available columns for merge
  merge_cols <- c("COWcode", "year", present_cols)
  leader_merge <- leader_data |>
    select(all_of(intersect(merge_cols, names(leader_data)))) |>
    distinct(COWcode, year, .keep_all = TRUE)

  spine_ideology <- spine |>
    left_join(
      leader_merge,
      by = c("COWcode_a" = "COWcode", "year" = "year")
    )

  # Report merge coverage
  if ("sidea_revisionist_domestic" %in% names(spine_ideology)) {
    n_matched <- sum(!is.na(spine_ideology$sidea_revisionist_domestic))
    message(sprintf(
      "[03] sidea_revisionist_domestic: %d rows matched (%.1f%%)",
      n_matched, 100 * n_matched / nrow(spine_ideology)
    ))
  }
} else {
  warning("[03] No leader data could be built. spine_ideology will equal spine_conflict.")
  spine_ideology <- spine
}

# -----------------------------------------------------------------------------
# 8. Save
# -----------------------------------------------------------------------------
saveRDS(spine_ideology, here("data", "spine_ideology.rds"))

message("[03_build_grave_d_ideology.R] Saved: data/spine_ideology.rds")
message("[03_build_grave_d_ideology.R] Done.")
