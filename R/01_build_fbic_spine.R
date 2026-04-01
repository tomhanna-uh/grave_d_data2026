# =============================================================================
# 01_build_fbic_spine.R
# Build the directed dyad-year panel spine from the FBIC dataset
#
# Input:  source_data/fbic/  -- FBIC dataset file(s)
# Output: data/spine_fbic.rds
#
# The FBIC dataset provides the dyadic connectivity "bandwidth" variables
# and serves as the structural spine for the GRAVE-D master dataset.
# All other data sources are merged onto this spine.
#
# FBIC Variables built:
#   bandwidth, economicbandwidth, politicalbandwidth,
#   securitybandwidth
# Identification variables added:
#   COWcode_a, COWcode_b, year, iso3a, iso3b, unregiona, unregionb
# =============================================================================

source(here::here("R", "00_packages.R"))

message("[01_build_fbic_spine.R] Starting FBIC spine construction...")

# -----------------------------------------------------------------------------
# 1. Locate FBIC source file
# -----------------------------------------------------------------------------
# Expected file: source_data/fbic/FBIC_dyadic.csv (or .dta)
# Adjust filename as needed based on downloaded FBIC release.

fbic_path_csv <- here("source_data", "fbic", "FBIC_dyadic.csv")
fbic_path_dta <- here("source_data", "fbic", "FBIC_dyadic.dta")

# Expected MD5 hashes to ensure data integrity
# Configured via environment variables for security and flexibility
expected_fbic_csv_md5 <- Sys.getenv("FBIC_CSV_MD5", unset = "")
expected_fbic_dta_md5 <- Sys.getenv("FBIC_DTA_MD5", unset = "")

if (file.exists(fbic_path_csv)) {
  if (nzchar(expected_fbic_csv_md5)) {
    message("[01] Verifying FBIC CSV checksum...")
    actual_md5 <- unname(tools::md5sum(fbic_path_csv))
    if (actual_md5 != expected_fbic_csv_md5) {
      stop(
        "[01_build_fbic_spine.R] SECURITY ERROR: FBIC CSV checksum mismatch.\n",
        "  Expected: ", expected_fbic_csv_md5, "\n",
        "  Actual:   ", actual_md5, "\n",
        "  File may be corrupted or tampered with."
      )
    }
  } else {
    message("[01] WARNING: FBIC CSV checksum validation skipped (no expected hash configured).")
  }
  message("[01] Reading FBIC from CSV...")
  fbic_raw <- as_tibble(data.table::fread(file = fbic_path_csv))
} else if (file.exists(fbic_path_dta)) {
  if (nzchar(expected_fbic_dta_md5)) {
    message("[01] Verifying FBIC DTA checksum...")
    actual_md5 <- unname(tools::md5sum(fbic_path_dta))
    if (actual_md5 != expected_fbic_dta_md5) {
      stop(
        "[01_build_fbic_spine.R] SECURITY ERROR: FBIC DTA checksum mismatch.\n",
        "  Expected: ", expected_fbic_dta_md5, "\n",
        "  Actual:   ", actual_md5, "\n",
        "  File may be corrupted or tampered with."
      )
    }
  } else {
    message("[01] WARNING: FBIC DTA checksum validation skipped (no expected hash configured).")
  }
  message("[01] Reading FBIC from Stata .dta...")
  fbic_raw <- haven::read_dta(fbic_path_dta)
} else {
  stop(
    "[01_build_fbic_spine.R] FBIC source file not found.\n",
    "  Place FBIC_dyadic.csv or FBIC_dyadic.dta in: source_data/fbic/\n",
    "  Download from: https://fbicproject.com/"
  )
}

message(sprintf("[01] FBIC raw: %d rows x %d cols", nrow(fbic_raw), ncol(fbic_raw)))

# -----------------------------------------------------------------------------
# 2. Standardize column names
# -----------------------------------------------------------------------------
# FBIC uses iso3a/iso3b for country identifiers. We convert to COW codes.
# Bandwidth variables: check for lowercase names

fbic_raw <- fbic_raw |>
  rename_with(tolower)

# Core columns expected
fbic_required <- c("iso3a", "iso3b", "year", "bandwidth")
missing_cols <- setdiff(fbic_required, names(fbic_raw))
if (length(missing_cols) > 0) {
  stop(
    "[01] Missing required FBIC columns: ",
    paste(missing_cols, collapse = ", ")
  )
}

# -----------------------------------------------------------------------------
# 3. Convert ISO3 codes to COW codes
# -----------------------------------------------------------------------------

fbic_coded <- fbic_raw |>
  mutate(
    COWcode_a = countrycode(
      iso3a, origin = "iso3c", destination = "cown", warn = FALSE
    ),
    COWcode_b = countrycode(
      iso3b, origin = "iso3c", destination = "cown", warn = FALSE
    ),
    # UN Geographic regions
    unregiona = countrycode(
      iso3a, origin = "iso3c",
      destination = "un.regionsub.name", warn = FALSE
    ),
    unregionb = countrycode(
      iso3b, origin = "iso3c",
      destination = "un.regionsub.name", warn = FALSE
    )
  )

# Drop rows where COW codes could not be matched
n_before <- nrow(fbic_coded)
fbic_coded <- fbic_coded |>
  filter(!is.na(COWcode_a), !is.na(COWcode_b))
n_after <- nrow(fbic_coded)

message(sprintf(
  "[01] Dropped %d rows where COW codes could not be assigned (%.1f%%)",
  n_before - n_after, 100 * (n_before - n_after) / n_before
))

# -----------------------------------------------------------------------------
# 4. Filter to 1946-2020 coverage window
# -----------------------------------------------------------------------------

fbic_filtered <- fbic_coded |>
  filter(year >= 1946L, year <= 2020L)

message(sprintf(
  "[01] After year filter (1946-2020): %d rows x %d cols",
  nrow(fbic_filtered), ncol(fbic_filtered)
))

# -----------------------------------------------------------------------------
# 5. Select and rename bandwidth variables
# -----------------------------------------------------------------------------
# FBIC bandwidth variable naming may vary by release; handle common variants

bandwidth_vars <- c(
  "bandwidth", "economicbandwidth", "politicalbandwidth",
  "securitybandwidth"
)

# Check which bandwidth vars are present
present_bw <- intersect(bandwidth_vars, names(fbic_filtered))
missing_bw <- setdiff(bandwidth_vars, names(fbic_filtered))

if (length(missing_bw) > 0) {
  warning(
    "[01] Some bandwidth variables not found in FBIC: ",
    paste(missing_bw, collapse = ", "),
    "\n They will be set to NA in the spine."
  )
  for (v in missing_bw) {
    fbic_filtered[[v]] <- NA_real_
  }
}

# -----------------------------------------------------------------------------
# 6. Build final spine
# -----------------------------------------------------------------------------

spine <- fbic_filtered |>
  select(
    # Identification
    COWcode_a, COWcode_b, year, iso3a, iso3b, unregiona, unregionb,
    # Bandwidth variables
    all_of(bandwidth_vars)
  ) |>
  # Remove self-directed dyads
  filter(COWcode_a != COWcode_b) |>
  # Create unique dyad identifier
  mutate(
    dyad = paste0(
      sprintf("%03d", COWcode_a), "_",
      sprintf("%03d", COWcode_b)
    )
  ) |>
  arrange(COWcode_a, COWcode_b, year)

message(sprintf(
  "[01] Spine: %d directed dyad-year observations | %d unique dyads | years %d-%d",
  nrow(spine),
  n_distinct(spine$dyad),
  min(spine$year),
  max(spine$year)
))

# -----------------------------------------------------------------------------
# 7. Save intermediate output
# -----------------------------------------------------------------------------

dir.create(here("data"), showWarnings = FALSE)
saveRDS(spine, here("data", "spine_fbic.rds"))

message("[01_build_fbic_spine.R] Saved: data/spine_fbic.rds")
message("[01_build_fbic_spine.R] Done.")

rm(fbic_raw, fbic_coded, fbic_filtered)
