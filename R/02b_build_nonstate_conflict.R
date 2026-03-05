# =============================================================================
# 02b_build_nonstate_conflict.R
# Merge UCDP Non-State Conflict indicators onto the FBIC spine
#
# Input:  data/spine_conflict.rds        (from 02_build_conflict.R)
#         source_data/ucdp/nonstate_v251.csv  (UCDP Non-State Conflict v25.1)
# Output: data/spine_nonstate.rds
#
# UCDP Non-State Conflict = armed conflict between non-state groups
#   (neither side is a government). Data covers 1989-2024.
#   Unit of observation: conflict-dyad-year.
#   Location variable (gwno_location) identifies the country where
#   fighting occurred, using Gleditsch-Ward codes.
#
# Because non-state conflicts have no state "sides," the relevant
# information for the directed dyad spine is whether a country
# experienced non-state conflict on its territory in a given year.
# This is merged as a monadic (country-year) attribute for both
# Country A (sender) and Country B (target).
#
# Variables built:
#   nonstate_conflict_a/b      -- Binary: any non-state conflict on territory
#   nonstate_conflict_count_a/b -- Count of distinct non-state conflicts
#   nonstate_fatalities_best_a/b -- Best estimate fatalities (summed)
#   nonstate_fatalities_low_a/b  -- Low estimate fatalities (summed)
#   nonstate_fatalities_high_a/b -- High estimate fatalities (summed)
#
# NAs are coded to 0 (no conflict).
# =============================================================================

source(here::here("R", "00_packages.R"))

message("[02b_build_nonstate_conflict.R] Starting UCDP non-state conflict merge...")

# -----------------------------------------------------------------------------
# 1. Load spine
# -----------------------------------------------------------------------------
spine_path <- here("data", "spine_conflict.rds")
if (!file.exists(spine_path)) {
  stop(
    "[02b] Spine not found. Run R/02_build_conflict.R first.\n",
    "  Expected: data/spine_conflict.rds"
  )
}
spine <- readRDS(spine_path)
message(sprintf("[02b] Loaded spine: %d rows", nrow(spine)))

# -----------------------------------------------------------------------------
# 2. Load UCDP Non-State Conflict Dataset v25.1
# -----------------------------------------------------------------------------
# Download from: https://ucdp.uu.se/downloads/
# File: nonstate_v251.csv
ucdp_path <- here("source_data", "ucdp", "nonstate_v251.csv")

if (!file.exists(ucdp_path)) {
  # Try alternate filenames
  ucdp_files <- list.files(
    here("source_data", "ucdp"),
    pattern = "nonstate.*\\.csv$",
    full.names = TRUE,
    ignore.case = TRUE
  )
  if (length(ucdp_files) > 0) {
    ucdp_path <- ucdp_files[1]
    message(sprintf("[02b] Found UCDP file: %s", basename(ucdp_path)))
  } else {
    stop(
      "[02b] UCDP Non-State Conflict file not found.\n",
      "  Place nonstate_v251.csv in: source_data/ucdp/\n",
      "  Download from: https://ucdp.uu.se/downloads/"
    )
  }
}

ucdp_raw <- as_tibble(data.table::fread(file = ucdp_path))
message(sprintf("[02b] UCDP raw: %d rows x %d cols", nrow(ucdp_raw), ncol(ucdp_raw)))

# Standardize column names to lowercase
ucdp_raw <- ucdp_raw |> rename_with(tolower)

# -----------------------------------------------------------------------------
# 3. Expand gwno_location to one row per country-conflict-year
# -----------------------------------------------------------------------------
# gwno_location can be comma-separated when conflict spans multiple countries.
# We need one row per (location_country, conflict, year) to properly aggregate.

if (!"gwno_location" %in% names(ucdp_raw)) {
  # Try alternate column name
  gwno_col <- grep("gwno.*loc|gwnoloc", names(ucdp_raw), value = TRUE, ignore.case = TRUE)
  if (length(gwno_col) > 0) {
    ucdp_raw <- ucdp_raw |> rename(gwno_location = !!sym(gwno_col[1]))
    message(sprintf("[02b] Renamed '%s' to 'gwno_location'", gwno_col[1]))
  } else {
    stop("[02b] Cannot find gwno_location column in UCDP data.")
  }
}

# Ensure gwno_location is character for splitting
ucdp_raw <- ucdp_raw |>
  mutate(gwno_location = as.character(gwno_location))

# Expand comma-separated location codes
ucdp_expanded <- ucdp_raw |>
  select(conflict_id, dyad_id, year,
         best_fatality_estimate, low_fatality_estimate, high_fatality_estimate,
         gwno_location) |>
  separate_rows(gwno_location, sep = ",\\s*") |>
  mutate(gwno_location = as.integer(trimws(gwno_location))) |>
  filter(!is.na(gwno_location))

message(sprintf("[02b] After expanding locations: %d rows", nrow(ucdp_expanded)))

# -----------------------------------------------------------------------------
# 4. Convert Gleditsch-Ward codes to COW codes
# -----------------------------------------------------------------------------
ucdp_expanded <- ucdp_expanded |>
  mutate(
    COWcode = countrycode::countrycode(
      gwno_location,
      origin = "gwn",
      destination = "cown",
      warn = FALSE
    )
  )

# Report any unmatched GW codes
unmatched <- ucdp_expanded |>
  filter(is.na(COWcode)) |>
  distinct(gwno_location)

if (nrow(unmatched) > 0) {
  message(sprintf(
    "[02b] WARNING: %d GW codes could not be mapped to COW: %s",
    nrow(unmatched),
    paste(unmatched$gwno_location, collapse = ", ")
  ))
}

# Drop rows without a valid COW code
ucdp_expanded <- ucdp_expanded |> filter(!is.na(COWcode))

# -----------------------------------------------------------------------------
# 5. Aggregate to country-year level
# -----------------------------------------------------------------------------
# For each country-year: count conflicts, sum fatalities
nonstate_by_country <- ucdp_expanded |>
  group_by(COWcode, year) |>
  summarise(
    nonstate_conflict       = 1L,
    nonstate_conflict_count = n_distinct(conflict_id),
    nonstate_fatalities_best = sum(best_fatality_estimate, na.rm = TRUE),
    nonstate_fatalities_low  = sum(low_fatality_estimate, na.rm = TRUE),
    nonstate_fatalities_high = sum(high_fatality_estimate, na.rm = TRUE),
    .groups = "drop"
  )

message(sprintf(
  "[02b] Non-state conflict summary: %d country-years with conflict",
  nrow(nonstate_by_country)
))

# -----------------------------------------------------------------------------
# 6. Merge onto spine as Country A (sender) attributes
# -----------------------------------------------------------------------------
nonstate_a <- nonstate_by_country |>
  rename_with(~ paste0(.x, "_a"), .cols = -c(COWcode, year)) |>
  rename(COWcode_a = COWcode)

spine_ns <- spine |>
  left_join(nonstate_a, by = c("COWcode_a", "year"))

# -----------------------------------------------------------------------------
# 7. Merge onto spine as Country B (target) attributes
# -----------------------------------------------------------------------------
nonstate_b <- nonstate_by_country |>
  rename_with(~ paste0(.x, "_b"), .cols = -c(COWcode, year)) |>
  rename(COWcode_b = COWcode)

spine_ns <- spine_ns |>
  left_join(nonstate_b, by = c("COWcode_b", "year"))

# -----------------------------------------------------------------------------
# 8. Zero-fill NAs (no conflict = 0)
# -----------------------------------------------------------------------------
ns_cols <- grep("^nonstate_", names(spine_ns), value = TRUE)

for (col in ns_cols) {
  spine_ns[[col]] <- if_else(is.na(spine_ns[[col]]), 0L, as.integer(spine_ns[[col]]))
}

message(sprintf(
  "[02b] After merge: %d rows | %d dyad-years with nonstate conflict (A) | %d (B)",
  nrow(spine_ns),
  sum(spine_ns$nonstate_conflict_a > 0),
  sum(spine_ns$nonstate_conflict_b > 0)
))

# -----------------------------------------------------------------------------
# 9. Save
# -----------------------------------------------------------------------------
saveRDS(spine_ns, here("data", "spine_nonstate.rds"))
message("[02b_build_nonstate_conflict.R] Saved: data/spine_nonstate.rds")
message("[02b_build_nonstate_conflict.R] Done.")

# Cleanup
rm(ucdp_raw, ucdp_expanded, nonstate_by_country, nonstate_a, nonstate_b, spine)
gc()
