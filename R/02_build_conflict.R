# =============================================================================
# 02_build_conflict.R
# Merge MIDs v4.0 conflict outcomes onto the FBIC spine
#
# Input:  data/spine_fbic.rds      (from 01_build_fbic_spine.R)
#         source_data/cow/          (MIDs v4.0 dyadic dataset)
# Output: data/spine_conflict.rds
#
# Variables built:
#   hihosta          -- Highest Hostility Level Side A (ordinal 1-5)
#   mid_initiated    -- Binary: 1 if hihosta >= 2 (MID initiated)
#   targets_democracy -- Binary: 1 if v2x_libdem_b >= 0.5 (added in step 04)
# =============================================================================

source(here::here("R", "00_packages.R"))

message("[02_build_conflict.R] Starting MIDs conflict merge...")

# -----------------------------------------------------------------------------
# 1. Load spine
# -----------------------------------------------------------------------------
spine_path <- here("data", "spine_fbic.rds")
if (!file.exists(spine_path)) {
  stop(
    "[02] Spine not found. Run R/01_build_fbic_spine.R first.\n",
    "  Expected: data/spine_fbic.rds"
  )
}
spine <- readRDS(spine_path)
message(sprintf("[02] Loaded spine: %d rows", nrow(spine)))

# -----------------------------------------------------------------------------
# 2. Load MIDs v4.0 dyadic dataset
# -----------------------------------------------------------------------------
# Expected file: source_data/cow/dyadic_mid_4.02.csv (or .dta)
# MIDs are a COW product; raw files live under source_data/cow/
# Download from: https://correlatesofwar.org/data-sets/MIDs
# Key variable: hihosta = highest hostility level for Side A initiator

mids_path_csv <- here("source_data", "cow", "dyadic_mid_4.02.csv")
mids_path_dta <- here("source_data", "cow", "dyadic_mid_4.02.dta")

if (file.exists(mids_path_csv)) {
  mids_raw <- as_tibble(data.table::fread(file = mids_path_csv))
} else if (file.exists(mids_path_dta)) {
  mids_raw <- haven::read_dta(mids_path_dta)
} else {
  # Try alternate filenames in source_data/cow/
  mids_files <- list.files(
    here("source_data", "cow"),
    pattern = ".*mid.*\\.csv$|.*mid.*\\.dta$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(mids_files) > 0) {
    message(sprintf("[02] Found MIDs file: %s", mids_files[1]))
    if (grepl("\\.csv$", mids_files[1])) {
      mids_raw <- as_tibble(data.table::fread(file = mids_files[1]))
    } else {
      mids_raw <- haven::read_dta(mids_files[1])
    }
  } else {
    stop(
      "[02_build_conflict.R] MIDs source file not found.\n",
      "  Place dyadic MIDs v4.0 file in: source_data/cow/\n",
      "  Download from: https://correlatesofwar.org/data-sets/MIDs"
    )
  }
}

message(sprintf("[02] MIDs raw: %d rows x %d cols", nrow(mids_raw), ncol(mids_raw)))

# -----------------------------------------------------------------------------
# 3. Standardize MIDs column names
# -----------------------------------------------------------------------------
mids_raw <- mids_raw |>
  rename_with(tolower)

# Identify COW code columns (vary by MIDs release version)
# v4.02 uses: ccode1, ccode2, year, hihosta (for directed dyadic)
# Check for common naming variants
if ("statea" %in% names(mids_raw) && "stateb" %in% names(mids_raw)) {
        mids_raw <- mids_raw |>
                rename(COWcode_a = statea, COWcode_b = stateb)
} else if ("ccode1" %in% names(mids_raw) && "ccode2" %in% names(mids_raw)) {
        mids_raw <- mids_raw |>
                rename(COWcode_a = ccode1, COWcode_b = ccode2)
}


# Ensure hihosta is present
if (!"hihosta" %in% names(mids_raw)) {
  # Try to find highest hostility variant names
  hh_col <- grep("^hihost|^hostlev", names(mids_raw), value = TRUE)
  if (length(hh_col) > 0) {
    mids_raw <- mids_raw |> rename(hihosta = !!sym(hh_col[1]))
    message(sprintf("[02] Renamed '%s' to 'hihosta'", hh_col[1]))
  } else {
    stop("[02] Cannot find highest hostility level column in MIDs data.")
  }
}

# -----------------------------------------------------------------------------
# 4. Build dyadic MID conflict indicators
# Keep one row per dyad-year: max hihosta if multiple MIDs in same year
# -----------------------------------------------------------------------------
mids_dyadic <- mids_raw |>
  filter(!is.na(COWcode_a), !is.na(COWcode_b)) |>
  select(COWcode_a, COWcode_b, year, hihosta) |>
  group_by(COWcode_a, COWcode_b, year) |>
  summarise(
    hihosta = max(hihosta, na.rm = TRUE),
    .groups = "drop"
  ) |>
  mutate(
    hihosta = as.integer(hihosta),
    mid_initiated = as.integer(hihosta >= 2L)
  )

message(sprintf(
  "[02] MIDs prepared: %d dyad-year rows, %d MID-initiated obs",
  nrow(mids_dyadic), sum(mids_dyadic$mid_initiated, na.rm = TRUE)
))

# -----------------------------------------------------------------------------
# 5. Left-join MIDs onto spine
# All spine rows are retained; non-conflict years get hihosta=0, mid_initiated=0
# -----------------------------------------------------------------------------
spine_conflict <- spine |>
  left_join(
    mids_dyadic,
    by = c("COWcode_a", "COWcode_b", "year")
  ) |>
  mutate(
    # Rows with no MID get coded as 0 (no conflict)
    hihosta       = if_else(is.na(hihosta), 0L, hihosta),
    mid_initiated = if_else(is.na(mid_initiated), 0L, mid_initiated)
  )

message(sprintf(
  "[02] After merge: %d rows | %d MID-initiated dyad-years (%.2f%%)",
  nrow(spine_conflict),
  sum(spine_conflict$mid_initiated),
  100 * mean(spine_conflict$mid_initiated)
))

# -----------------------------------------------------------------------------
# 6. Add peace years variables
# -----------------------------------------------------------------------------
spine_conflict <- spine_conflict |>
  arrange(dyad, year) |>
  group_by(dyad) |>
  mutate(
    conflict_year = if_else(mid_initiated == 1L, year, NA_integer_),
    last_conflict = cummax(if_else(is.na(conflict_year), 0L, conflict_year)),
    peace_years   = if_else(last_conflict == 0L, 35L, year - last_conflict),
    t  = peace_years,
    t2 = t^2,
    t3 = t^3
  ) |>
  ungroup() |>
  select(-conflict_year, -last_conflict)

# -----------------------------------------------------------------------------
# 7. Save
# -----------------------------------------------------------------------------
saveRDS(spine_conflict, here("data", "spine_conflict.rds"))

message("[02_build_conflict.R] Saved: data/spine_conflict.rds")
message("[02_build_conflict.R] Done.")
