# =============================================================================
# 04_build_controls.R
# Merge control variables from multiple sources onto the ideology spine
#
# Input:  data/spine_ideology.rds          (from 03_build_grave_d_ideology.R)
#         source_data/atop/                (ATOP alliance data)
#         source_data/controls/cinc/       (CINC / National Material Capabilities)
#         source_data/cow/WRP_national.csv (COW World Religions)
#         source_data/econ/ross_oil_gas/   (Ross oil and gas)
#         source_data/econ/maddison/       (Maddison GDP data)
#         source_data/econ/swiid/          (SWIID inequality)
#         source_data/econ/fraser_institute/ (black market exchange rates)
#         source_data/econ/relational_export_dataset/ (trade flows)
#         V-Dem R package                  (regime and democracy measures)
# Output: data/spine_controls.rds
# =============================================================================
source(here::here("R", "00_packages.R"))

message("[04_build_controls.R] Starting controls merge...")

spine <- readRDS(here("data", "spine_ideology.rds"))
message(sprintf("[04] Loaded spine_ideology: %d rows", nrow(spine)))

# -----------------------------------------------------------------------------
# 1. V-Dem (via R package, not flat file)
# -----------------------------------------------------------------------------
# V-Dem data is accessed via the vdemdata R package. If the package is not
# installed, this section is skipped and V-Dem variables will be absent.

if (requireNamespace("vdemdata", quietly = TRUE)) {
  message("[04] Loading V-Dem from vdemdata package...")
  vdem_data <- vdemdata::vdem |>
    as_tibble() |>
    select(
      COWcode = COWcode, year = year,
      v2x_libdem, v2x_corr,
      v2exl_legitideol, v2exl_legitperf, v2exl_legitlead,
      v2exl_legitratio, v2x_polyarchy,
      v2pepwrses, v2pepwrsoc, v2x_cspart,
      v2dlreason, v2dlcommon, v2dlcountr
    ) |>
    filter(!is.na(COWcode))
  message(sprintf("[04] V-Dem: %d country-year rows", nrow(vdem_data)))
} else {
  warning("[04] vdemdata package not installed. V-Dem variables will be absent.")
  vdem_data <- NULL
}

# -----------------------------------------------------------------------------
# 2. CINC (National Material Capabilities)
# -----------------------------------------------------------------------------
cinc_files <- list.files(
  here("source_data", "controls", "cinc"),
  pattern = ".*\\.(csv|dta)$", full.names = TRUE, ignore.case = TRUE
)
if (length(cinc_files) > 0) {
  message(sprintf("[04] Found CINC file: %s", cinc_files[1]))
  if (grepl("\\.csv$", cinc_files[1])) {
    cinc_data <- as_tibble(data.table::fread(cinc_files[1]))
  } else {
    cinc_data <- haven::read_dta(cinc_files[1])
  }
  cinc_data <- cinc_data |> rename_with(tolower)
  if ("ccode" %in% names(cinc_data)) cinc_data <- cinc_data |> rename(COWcode = ccode)
  if ("cowcode" %in% names(cinc_data)) cinc_data <- cinc_data |> rename(COWcode = cowcode)
  cinc_data <- cinc_data |> select(COWcode, year, cinc) |> filter(!is.na(cinc))
  message(sprintf("[04] CINC: %d country-year rows", nrow(cinc_data)))
} else {
  warning("[04] No CINC file found in source_data/controls/cinc/")
  cinc_data <- NULL
}

# -----------------------------------------------------------------------------
# 3. ATOP (Alliance Treaty Obligations and Provisions)
# -----------------------------------------------------------------------------
# Expected file: atop5_1ddyr_NNA.csv (directed dyad-year, non-missing)
atop_path <- here("source_data", "atop", "atop5_1ddyr_NNA.csv")
if (file.exists(atop_path)) {
  atop_data <- as_tibble(data.table::fread(atop_path)) |>
    rename_with(tolower)
  # ATOP ddyr uses statea/stateb (COW codes) + year
  # Rename to match spine keys for merge in section 6c
  if (all(c("statea", "stateb", "year") %in% names(atop_data))) {
    atop_data <- atop_data |>
      rename(COWcode_a = statea, COWcode_b = stateb)
  }
  message(sprintf("[04] ATOP: %d rows x %d cols", nrow(atop_data), ncol(atop_data)))
} else {
  # Fallback: try any CSV/DTA in source_data/atop/
  atop_files <- list.files(
    here("source_data", "atop"),
    pattern = ".*ddyr.*\\.csv$", full.names = TRUE, ignore.case = TRUE
  )
  if (length(atop_files) > 0) {
    atop_data <- as_tibble(data.table::fread(atop_files[1])) |>
      rename_with(tolower)
    if (all(c("statea", "stateb", "year") %in% names(atop_data))) {
      atop_data <- atop_data |>
        rename(COWcode_a = statea, COWcode_b = stateb)
    }
    message(sprintf("[04] ATOP (fallback): %s | %d rows", basename(atop_files[1]), nrow(atop_data)))
  } else {
    warning("[04] atop5_1ddyr_NNA.csv not found in source_data/atop/")
    atop_data <- NULL
  }
}

# -----------------------------------------------------------------------------
# 4. COW World Religions Project
# -----------------------------------------------------------------------------
wrp_path <- here("source_data", "cow", "WRP_national.csv")
if (file.exists(wrp_path)) {
  wrp_data <- as_tibble(data.table::fread(wrp_path)) |> rename_with(tolower)
  if ("ccode" %in% names(wrp_data)) wrp_data <- wrp_data |> rename(COWcode = ccode)
  if ("cowcode" %in% names(wrp_data)) wrp_data <- wrp_data |> rename(COWcode = cowcode)
    if ("state" %in% names(wrp_data)) wrp_data <- wrp_data |> rename(COWcode = state)
  message(sprintf("[04] WRP religions: %d rows", nrow(wrp_data)))
} else {
  warning("[04] WRP_national.csv not found in source_data/cow/")
  wrp_data <- NULL
}

# -----------------------------------------------------------------------------
# 5. Economic controls (source_data/econ/ subdirectories)
# -----------------------------------------------------------------------------

# 5a. Ross oil and gas
ross_files <- list.files(
  here("source_data", "econ", "ross_oil_gas"),
  pattern = ".*\\.(csv|dta)$", full.names = TRUE, ignore.case = TRUE
)
if (length(ross_files) > 0) {
  message(sprintf("[04] Found Ross file: %s", ross_files[1]))
  if (grepl("\\.csv$", ross_files[1])) {
    ross_data <- as_tibble(data.table::fread(ross_files[1]))
  } else {
    ross_data <- haven::read_dta(ross_files[1])
  }
  ross_data <- ross_data |> rename_with(tolower)
  if ("ccode" %in% names(ross_data)) ross_data <- ross_data |> rename(COWcode = ccode)
  if ("cowcode" %in% names(ross_data)) ross_data <- ross_data |> rename(COWcode = cowcode)
  message(sprintf("[04] Ross: %d rows", nrow(ross_data)))
} else {
  ross_data <- NULL
}

# 5b. Maddison GDP
maddison_files <- list.files(
  here("source_data", "econ", "maddison"),
  pattern = ".*\\.(csv|dta|xlsx)$", full.names = TRUE, ignore.case = TRUE
)
if (length(maddison_files) > 0) {
  message(sprintf("[04] Found Maddison file: %s", maddison_files[1]))
  if (grepl("\\.csv$", maddison_files[1])) {
    maddison_data <- as_tibble(data.table::fread(maddison_files[1]))
  } else if (grepl("\\.dta$", maddison_files[1])) {
    maddison_data <- haven::read_dta(maddison_files[1])
  } else {
    maddison_data <- readxl::read_excel(maddison_files[1])
  }
  maddison_data <- maddison_data |> rename_with(tolower)
  if ("ccode" %in% names(maddison_data)) maddison_data <- maddison_data |> rename(COWcode = ccode)
  if ("cowcode" %in% names(maddison_data)) maddison_data <- maddison_data |> rename(COWcode = cowcode)
  message(sprintf("[04] Maddison: %d rows", nrow(maddison_data)))
} else {
  maddison_data <- NULL
}

# 5c. SWIID inequality
swiid_files <- list.files(
  here("source_data", "econ", "swiid"),
  pattern = ".*\\.(csv|dta|rds)$", full.names = TRUE, ignore.case = TRUE
)
if (length(swiid_files) > 0) {
  message(sprintf("[04] Found SWIID file: %s", swiid_files[1]))
  if (grepl("\\.csv$", swiid_files[1])) {
    swiid_data <- as_tibble(data.table::fread(swiid_files[1]))
  } else if (grepl("\\.rds$", swiid_files[1])) {
    swiid_data <- readRDS(swiid_files[1])
  } else {
    swiid_data <- haven::read_dta(swiid_files[1])
  }
  swiid_data <- swiid_data |> rename_with(tolower)
  if ("ccode" %in% names(swiid_data)) swiid_data <- swiid_data |> rename(COWcode = ccode)
  if ("cowcode" %in% names(swiid_data)) swiid_data <- swiid_data |> rename(COWcode = cowcode)
  message(sprintf("[04] SWIID: %d rows", nrow(swiid_data)))
} else {
  swiid_data <- NULL
}

# 5d. Fraser Institute black market exchange rates
fraser_path <- here("source_data", "econ", "fraser_institute", "black_market_exchange_rates.csv")
if (file.exists(fraser_path)) {
  fraser_data <- as_tibble(data.table::fread(fraser_path)) |> rename_with(tolower)
  if ("ccode" %in% names(fraser_data)) fraser_data <- fraser_data |> rename(COWcode = ccode)
  if ("cowcode" %in% names(fraser_data)) fraser_data <- fraser_data |> rename(COWcode = cowcode)
  message(sprintf("[04] Fraser: %d rows", nrow(fraser_data)))
} else {
  fraser_data <- NULL
}

# 5e. Relational export dataset
export_files <- list.files(
  here("source_data", "econ", "relational_export_dataset"),
  pattern = ".*\\.(csv|dta)$", full.names = TRUE, ignore.case = TRUE
)
if (length(export_files) > 0) {
  message(sprintf("[04] Found export file: %s", export_files[1]))
  if (grepl("\\.csv$", export_files[1])) {
    export_data <- as_tibble(data.table::fread(export_files[1]))
  } else {
    export_data <- haven::read_dta(export_files[1])
  }
  export_data <- export_data |> rename_with(tolower)
  message(sprintf("[04] Export data: %d rows", nrow(export_data)))
} else {
  export_data <- NULL
}

# -----------------------------------------------------------------------------
# 6. Merge all controls onto spine
# -----------------------------------------------------------------------------
# Country-year sources are merged twice: once for Side A, once for Side B.
# Dyad-year sources (ATOP, export) are merged on (COWcode_a, COWcode_b, year).

spine_controls <- spine

# 6a. V-Dem (country-year -> both sides)
if (!is.null(vdem_data)) {
  spine_controls <- spine_controls |>
    left_join(
      vdem_data |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)),
      by = c("COWcode_a" = "COWcode", "year")
    ) |>
    left_join(
      vdem_data |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)),
      by = c("COWcode_b" = "COWcode", "year")
    )
  message("[04] Merged V-Dem (both sides).")
}

# 6b. CINC (country-year -> both sides)
if (!is.null(cinc_data)) {
  spine_controls <- spine_controls |>
    left_join(
      cinc_data |> rename(cinc_a = cinc),
      by = c("COWcode_a" = "COWcode", "year")
    ) |>
    left_join(
      cinc_data |> rename(cinc_b = cinc),
      by = c("COWcode_b" = "COWcode", "year")
    )
  message("[04] Merged CINC (both sides).")
}

# 6c. ATOP (dyad-year -- already keyed as COWcode_a, COWcode_b, year)
if (!is.null(atop_data) &&
    all(c("COWcode_a", "COWcode_b", "year") %in% names(atop_data))) {
  # Select ATOP alliance indicator columns; adjust as needed
  atop_merge <- atop_data |>
    distinct(COWcode_a, COWcode_b, year, .keep_all = TRUE)
  spine_controls <- spine_controls |>
    left_join(atop_merge, by = c("COWcode_a", "COWcode_b", "year"))
  message(sprintf("[04] Merged ATOP: %d alliance columns.",
                  ncol(atop_merge) - 3))
} else if (!is.null(atop_data)) {
  message("[04] ATOP loaded but COWcode_a/COWcode_b/year keys not found. Skipping merge.")
}

# 6d. WRP religions (country-year -> both sides)
if (!is.null(wrp_data)) {
  # Select key religion percentage columns (adjust names to your WRP file)
  wrp_cols <- intersect(
    c("COWcode", "year", "chrstgenpct", "islmgenpct", "budgenpct", "hindgenpct"),
    names(wrp_data)
  )
  if (length(wrp_cols) >= 3) {
    wrp_clean <- wrp_data |> select(all_of(wrp_cols)) |> distinct(COWcode, year, .keep_all = TRUE)
    spine_controls <- spine_controls |>
      left_join(
        wrp_clean |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)),
        by = c("COWcode_a" = "COWcode", "year")
      ) |>
      left_join(
        wrp_clean |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)),
        by = c("COWcode_b" = "COWcode", "year")
      )
    message("[04] Merged WRP religions (both sides).")
  }
}

# 6e. Ross oil/gas (country-year -> both sides)
# TODO: Select specific Ross variables and merge similarly to CINC
if (!is.null(ross_data)) {
  message("[04] Ross loaded. Select specific variables and merge as needed.")
}

# 6f. Maddison GDP (country-year -> both sides)
# TODO: Select GDP variables and merge
if (!is.null(maddison_data)) {
  message("[04] Maddison loaded. Select specific variables and merge as needed.")
}

# 6g. SWIID (country-year -> both sides)
# TODO: Select Gini variables and merge
if (!is.null(swiid_data)) {
  message("[04] SWIID loaded. Select specific variables and merge as needed.")
}

# 6h. Fraser (country-year -> both sides)
# TODO: Select exchange rate variables and merge
if (!is.null(fraser_data)) {
  message("[04] Fraser loaded. Select specific variables and merge as needed.")
}

# 6i. Relational export data (dyad-year)
# TODO: Merge on dyadic keys
if (!is.null(export_data)) {
  message("[04] Export data loaded. Merge on dyadic keys as needed.")
}

# -----------------------------------------------------------------------------
# 6j. Construct GRAVE-D sidea_* ideology & support variables
# -----------------------------------------------------------------------------
# These are derived from V-Dem legitimation indicators (merged in 6a as
# _a / _b suffixed columns). The raw leader data from Archigos/Colgan/
# leader_ideology was attached in 03_build_grave_d_ideology.R.
#
# V-Dem source -> GRAVE-D target mapping:
#   v2exl_legitideol_a  -> sidea_revisionist_domestic (ideology-based legit)
#   v2exl_legitlead_a   -> sidea_dynamic_leader (personalist legit)
#   v2pepwrses_a        -> sidea_party_elite_support (power by SES)
#   v2pepwrsoc_a        -> sidea_ethnic_racial_support (power by social group)
#   v2x_cspart_a        -> sidea_rural_worker_support (civil society)
#   v2dlreason_a        -> sidea_winning_coalition_size (deliberation proxy)
#
# Thresholds and sub-type breakdowns (nationalist, socialist, religious,
# reactionary, separatist) require supplementary coding from Colgan or
# manual classification. Placeholders below use the continuous V-Dem
# scores directly; refine thresholds as needed.

if ("v2exl_legitideol_a" %in% names(spine_controls)) {
  spine_controls <- spine_controls |>
    mutate(
      # Ideology-based legitimation (continuous, higher = more ideological)
      sidea_revisionist_domestic = v2exl_legitideol_a,

      # Sub-types: these require external coding to disaggregate.
      # Placeholder: set to NA until Colgan/manual classification is added.
      sidea_nationalist_revisionist_domestic = NA_real_,
      sidea_socialist_revisionist_domestic   = NA_real_,
      sidea_religious_revisionist_domestic   = NA_real_,
      sidea_reactionary_revisionist_domestic = NA_real_,
      sidea_separatist_revisionist_domestic  = NA_real_,

      # Personalist/charismatic leader legitimation
      sidea_dynamic_leader = v2exl_legitlead_a
    )
  message("[04] Built sidea_revisionist_domestic, sidea_dynamic_leader from V-Dem.")
} else {
  message("[04] V-Dem legitimation columns not found; skipping sidea_* ideology.")
}

# Support group variables from V-Dem
if ("v2pepwrses_a" %in% names(spine_controls)) {
  spine_controls <- spine_controls |>
    mutate(
      sidea_party_elite_support    = v2pepwrses_a,
      sidea_ethnic_racial_support  = v2pepwrsoc_a,
      sidea_rural_worker_support   = v2x_cspart_a,
      sidea_military_support       = NA_real_,   # No direct V-Dem proxy
      sidea_religious_support      = NA_real_,   # Needs WRP or manual coding
      sidea_winning_coalition_size = v2dlreason_a
    )
  message("[04] Built sidea_*_support variables from V-Dem.")
} else {
  message("[04] V-Dem power distribution columns not found; skipping support vars.")
}

# -----------------------------------------------------------------------------
# 7. Derived variables
# -----------------------------------------------------------------------------
spine_controls <- spine_controls |>
  mutate(
    targets_democracy = if_else(
      "v2x_libdem_b" %in% names(spine_controls) & !is.na(v2x_libdem_b),
      if_else(v2x_libdem_b >= 0.5, 1L, 0L),
      NA_integer_
    ),
    cold_war = if_else(year >= 1947 & year <= 1991, 1L, 0L)
  )

message(sprintf(
  "[04] spine_controls: %d rows x %d cols",
  nrow(spine_controls), ncol(spine_controls)
))

# -----------------------------------------------------------------------------
# 8. Save
# -----------------------------------------------------------------------------
saveRDS(spine_controls, here("data", "spine_controls.rds"))
message("[04_build_controls.R] Saved: data/spine_controls.rds")
message("[04_build_controls.R] Done.")
