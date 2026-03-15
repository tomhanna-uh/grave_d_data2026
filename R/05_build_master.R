# =============================================================================
# 05_build_master.R
# Assemble the GRAVE-D directed dyadic master dataset
#
# Purpose:
#   Build the final dyadic GRAVE-D master dataset by merging the
#   intermediate spine, conflict, ideology, and controls objects, and
#   export both an internal R object and CSV files for external use.
#
# Inputs (from data/):
#   - data/spine_conflict.rds
#   - data/spine_nonstate.rds   (UCDP non-state conflict)
#   - data/spine_ideology.rds
#   - data/spine_nags.rds       (Dangerous Companions NAGs support)
#   - data/spine_controls.rds
#
# Outputs:
#   - data/GRAVE_D_Master.rds
#   - ready_data/GRAVE_D_Master.csv
# =============================================================================
source(here::here("R", "00_packages.R"))

message("[05_build_master.R] Assembling GRAVE-D master dataset...")

# -------------------------------------------------------------------------
# 1. LOAD INTERMEDIATE DATASETS
# -------------------------------------------------------------------------
spine_conflict  <- readRDS(here("data", "spine_conflict.rds"))
spine_ideology  <- readRDS(here("data", "spine_ideology.rds"))
spine_controls  <- readRDS(here("data", "spine_controls.rds"))

message("  Loaded: spine_conflict (", nrow(spine_conflict), " rows)")
message("  Loaded: spine_ideology (", nrow(spine_ideology), " rows)")
message("  Loaded: spine_controls (", nrow(spine_controls), " rows)")

# ----------------------------------------------------------------------------
# Quick NAG preservation check (added for this run)
# ----------------------------------------------------------------------------
message("[05] Checking NAG columns survived from 04...")
nags_cols <- names(spine_controls)[grepl("^nags_", names(spine_controls))]
print(paste("NAG columns found:", length(nags_cols)))
if (length(nags_cols) > 0) print(nags_cols)

# Load new intermediates (optional -- pipeline works without them)
spine_nonstate <- NULL
spine_nags     <- NULL

if (file.exists(here("data", "spine_nonstate.rds"))) {
  spine_nonstate <- readRDS(here("data", "spine_nonstate.rds"))
  message("  Loaded: spine_nonstate (", nrow(spine_nonstate), " rows)")
} else {
  message("  spine_nonstate.rds not found; skipping UCDP non-state conflict.")
}

if (file.exists(here("data", "spine_nags.rds"))) {
  spine_nags <- readRDS(here("data", "spine_nags.rds"))
  message("  Loaded: spine_nags (", nrow(spine_nags), " rows)")
} else {
  message("  spine_nags.rds not found; skipping NAGs support.")
}

# -------------------------------------------------------------------------
# 2. MERGE CONFLICT & IDEOLOGY
# -------------------------------------------------------------------------
grave_d <- spine_ideology

# -------------------------------------------------------------------------
# 3. ADD CONTROL VARIABLES
# -------------------------------------------------------------------------
key_cols <- c("COWcode_a", "COWcode_b", "year")

existing_cols <- names(grave_d)
new_control_cols <- setdiff(names(spine_controls), existing_cols)

if (length(new_control_cols) > 0) {
  grave_d <- grave_d |>
    left_join(
      spine_controls |> select(all_of(c(key_cols, new_control_cols))),
      by = key_cols
    )
  message("  Added ", length(new_control_cols), " new control columns from spine_controls.")
} else {
  message("  No new control columns to add (all already present).")
}

# -------------------------------------------------------------------------
# 3b. ADD UCDP NON-STATE CONFLICT VARIABLES
# -------------------------------------------------------------------------
if (!is.null(spine_nonstate)) {
  existing_cols <- names(grave_d)
  new_ns_cols <- setdiff(names(spine_nonstate), existing_cols)
  if (length(new_ns_cols) > 0) {
    grave_d <- grave_d |>
      left_join(
        spine_nonstate |> select(all_of(c(key_cols, new_ns_cols))),
        by = key_cols
      )
    # Zero-fill NAs for nonstate columns (no conflict = 0)
    for (col in new_ns_cols) {
      if (is.numeric(grave_d[[col]])) {
        grave_d[[col]] <- if_else(is.na(grave_d[[col]]), 0L, as.integer(grave_d[[col]]))
      }
    }
    message("  Added ", length(new_ns_cols), " UCDP non-state conflict columns.")
  } else {
    message("  No new non-state conflict columns to add (all already present).")
  }
}

# -------------------------------------------------------------------------
# 3c. ADD DANGEROUS COMPANIONS NAGs SUPPORT VARIABLES
# -------------------------------------------------------------------------
if (!is.null(spine_nags)) {
  existing_cols <- names(grave_d)
  new_nags_cols <- setdiff(names(spine_nags), existing_cols)
  if (length(new_nags_cols) > 0) {
    grave_d <- grave_d |>
      left_join(
        spine_nags |> select(all_of(c(key_cols, new_nags_cols))),
        by = key_cols
      )
    # Zero-fill NAs for NAGs columns (no support = 0)
    for (col in new_nags_cols) {
      if (is.numeric(grave_d[[col]])) {
        grave_d[[col]] <- if_else(is.na(grave_d[[col]]), 0L, as.integer(grave_d[[col]]))
      }
    }
    message("  Added ", length(new_nags_cols), " NAGs support columns.")
  } else {
    message("  No new NAGs columns to add (all already present).")
  }
}

# -------------------------------------------------------------------------
# 4. VARIABLE ENGINEERING: DERIVED DYADIC VARIABLES
# -------------------------------------------------------------------------
# Pre-check column availability (avoids . pronoun issues with |>)
has_islm  <- all(c("islmgenpct_a", "islmgenpct_b") %in% names(grave_d))
has_chrst <- all(c("chrstgenpct_a", "chrstgenpct_b") %in% names(grave_d))

grave_d <- grave_d |>
  mutate(
    mid_initiated = if_else(
      !is.na(hihosta) & hihosta >= 2, 1L, 0L
    ),
    islm_dist  = if (has_islm) abs(islmgenpct_a - islmgenpct_b) else NA_real_,
    chrst_dist = if (has_chrst) abs(chrstgenpct_a - chrstgenpct_b) else NA_real_
  )

# -------------------------------------------------------------------------
# 4b. REVISIONIST POTENTIAL (from data-2025/revisionist_potential.R)
# -------------------------------------------------------------------------
has_rev_inputs <- all(c("v2exl_legitideol_a", "v2exl_legitideol_b",
                        "v2x_libdem_a", "v2x_libdem_b") %in% names(grave_d))

if (has_rev_inputs) {
  # Step 1: Ideological extremity (distance from annual global median)
  grave_d <- grave_d |>
    group_by(year) |>
    mutate(
      global_med_ideol = median(v2exl_legitideol_a, na.rm = TRUE),
      ideol_extremity_a = abs(v2exl_legitideol_a - global_med_ideol),
      ideol_extremity_b = abs(v2exl_legitideol_b - global_med_ideol)
    ) |>
    ungroup()

  # Step 2: Inverted democratic constraint
  grave_d <- grave_d |>
    mutate(
      dem_constraint_inv_a = 1 - v2x_libdem_a,
      dem_constraint_inv_b = 1 - v2x_libdem_b
    )

  # Step 3: Z-score standardization and composite index
  grave_d <- grave_d |>
    mutate(
      z_legit_a = as.numeric(scale(v2exl_legitideol_a)),
      z_dem_a   = as.numeric(scale(dem_constraint_inv_a)),
      z_ext_a   = as.numeric(scale(ideol_extremity_a)),
      z_legit_b = as.numeric(scale(v2exl_legitideol_b)),
      z_dem_b   = as.numeric(scale(dem_constraint_inv_b)),
      z_ext_b   = as.numeric(scale(ideol_extremity_b)),
      rev_potential_a = (z_legit_a + z_dem_a + z_ext_a) / 3,
      rev_potential_b = (z_legit_b + z_dem_b + z_ext_b) / 3,
      revisionism_distance = abs(rev_potential_a - rev_potential_b)
    )
  message("  Built revisionist_potential variables (rev_potential_a/b, revisionism_distance).")
} else {
  message("  V-Dem libdem/legitideol not found; skipping revisionist_potential.")
}

# -------------------------------------------------------------------------
# 5. ADD UN GEOGRAPHIC REGION LABELS (if not already present)
# -------------------------------------------------------------------------
if (!"unregiona" %in% names(grave_d) && "COWcode_a" %in% names(grave_d)) {
  if (requireNamespace("countrycode", quietly = TRUE)) {
    grave_d <- grave_d |>
      mutate(
        unregiona = countrycode::countrycode(COWcode_a, "cown", "un.region.name", warn = FALSE),
        unregionb = countrycode::countrycode(COWcode_b, "cown", "un.region.name", warn = FALSE)
      )
    message("  Added unregiona/unregionb via countrycode package.")
  }
}

# -------------------------------------------------------------------------
# 6. CLEAN UP AND STANDARDISE COLUMN ORDER
# -------------------------------------------------------------------------
preferred_front <- c(
  "COWcode_a", "COWcode_b", "year", "dyad",
  "unregiona", "unregionb",
  "bandwidth", "economicbandwidth", "politicalbandwidth",
  "securitybandwidth", "socialbandwidth",
  "hihosta", "mid_initiated", "fuf_initiator",
  "targets_democracy", "cold_war",
  # Non-state conflict
  "nonstate_conflict_a", "nonstate_conflict_b",
  "nonstate_conflict_count_a", "nonstate_conflict_count_b",
  "nonstate_fatalities_best_a", "nonstate_fatalities_best_b",
  # NAGs support
  "nags_any_support", "nags_active_support", "nags_defacto_support",
  "nags_support_count",
  "nags_safe_haven", "nags_training", "nags_arms", "nags_funds", "nags_troops",
  # Revisionist potential
  "rev_potential_a", "rev_potential_b", "revisionism_distance",
  # Ideology
  "sidea_revisionist_domestic",
  "sidea_nationalist_revisionist_domestic",
  "sidea_socialist_revisionist_domestic",
  "sidea_religious_revisionist_domestic",
  "sidea_reactionary_revisionist_domestic",
  "sidea_separatist_revisionist_domestic",
  "sidea_dynamic_leader",
  "sidea_religious_support", "sidea_party_elite_support"
)

all_cols   <- names(grave_d)
front_cols <- intersect(preferred_front, all_cols)
rest_cols  <- setdiff(all_cols, front_cols)
grave_d    <- grave_d |> select(all_of(c(front_cols, rest_cols)))

# -------------------------------------------------------------------------
# 7b. Leader-expanded export (Side B leaders: Archigos + Colgan)
# -------------------------------------------------------------------------
grave_d_leaders <- grave_d

# --- Archigos Side B ---
archigos_path <- list.files(
  here("source_data", "archigos"),
  pattern = "archigos\\.tsv$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(archigos_path) > 0) {
  archigos <- as_tibble(data.table::fread(archigos_path[1])) |>
    rename_with(tolower)

  if ("ccode" %in% names(archigos)) archigos <- archigos |> rename(COWcode = ccode)
  if ("cowcode" %in% names(archigos)) archigos <- archigos |> rename(COWcode = cowcode)

  archigos <- archigos |>
    mutate(
      start_yr = as.integer(format(as.Date(startdate), "%Y")),
      end_yr   = as.integer(format(as.Date(enddate),   "%Y"))
    ) |>
    filter(!is.na(start_yr), !is.na(end_yr))

  archigos_cy <- archigos |>
    rowwise() |>
    mutate(year = list(seq(start_yr, end_yr))) |>
    ungroup() |>
    tidyr::unnest(year) |>
    select(-start_yr, -end_yr)

  archigos_b <- archigos_cy |>
    select(COWcode, year, any_of(c(
      "obsid", "leadid", "idacr", "leader", "startdate", "enddate",
      "entry", "exit", "exitcode", "prevtimesinoffice",
      "posttenurefate", "gender", "yrborn", "yrdied",
      "borndate", "deathdate", "dbpedia.uri",
      "num.entry", "num.exit", "num.exitcode", "num.posttenurefate"
    ))) |>
    rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)) |>
    distinct(COWcode, year, .keep_all = TRUE)

  grave_d_leaders <- grave_d_leaders |>
    left_join(archigos_b, by = c("COWcode_b" = "COWcode", "year"))
  message(sprintf("  Added %d Archigos Side B columns.", ncol(archigos_b) - 2))
} else {
  message("  Archigos file not found; skipping Side B Archigos merge.")
}

# --- Colgan Side B ---
colgan_files <- list.files(
  here("source_data", "colgan"),
  pattern = ".*\\.(csv|dta)$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(colgan_files) > 0) {
  if (grepl("\\.csv$", colgan_files[1])) {
    colgan <- as_tibble(data.table::fread(colgan_files[1]))
  } else {
    colgan <- haven::read_dta(colgan_files[1])
  }
  colgan <- colgan |> rename_with(tolower)
  if ("ccode" %in% names(colgan)) colgan <- colgan |> rename(COWcode = ccode)

  colgan_renames <- c(
    obsid_colgan = "obsid", leader_colgan = "leader",
    startdate_colgan = "startdate", enddate_colgan = "enddate",
    entry_colgan = "entry", prevtimesinoffice_colgan = "prevtimesinoffice",
    posttenurefate_colgan = "posttenurefate", gender_colgan = "gender"
  )
  colgan_renames <- colgan_renames[colgan_renames %in% names(colgan)]
  colgan <- colgan |> rename(!!!colgan_renames)

  colgan_b <- colgan |>
    select(COWcode, year, any_of(c(
      "obsid_colgan", "ccname", "leader_colgan",
      "startdate_colgan", "enddate_colgan", "entry_colgan",
      "prevtimesinoffice_colgan", "posttenurefate_colgan", "gender_colgan",
      "fties", "ftcur", "stabb", "age0", "startobs", "endobs", "age", "numld",
      "onsets", "revonsets", "sideaonsets",
      "force_onsets", "force_revonsets", "force_sideaonsets", "nonrevonsets",
      "usedforce", "irregulartransition", "foundingleader", "foreigninstall",
      "radicalideology", "democratizing", "revolutionaryleader", "ambiguouscoding",
      "chg_executivepower", "chg_politicalideology", "chg_nameofcountry",
      "chg_propertyowernship", "chg_womenandethnicstatus",
      "chg_religioningovernment", "chg_revolutionarycommittee",
      "totalcategorieschanged", "revage", "radrestrict"
    ))) |>
    rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)) |>
    distinct(COWcode, year, .keep_all = TRUE)

  grave_d_leaders <- grave_d_leaders |>
    left_join(colgan_b, by = c("COWcode_b" = "COWcode", "year"))
  message(sprintf("  Added %d Colgan Side B columns.", ncol(colgan_b) - 2))
} else {
  message("  Colgan file not found; skipping Side B Colgan merge.")
}

# --- Save leader-expanded export ---
readr::write_csv(
  grave_d_leaders,
  here("ready_data", "GRAVE_D_Master_with_Leaders.csv")
)
message(sprintf(
  "  -> ready_data/GRAVE_D_Master_with_Leaders.csv (%d rows x %d cols)",
  nrow(grave_d_leaders), ncol(grave_d_leaders)
))

# -------------------------------------------------------------------------
# 7. SAVE OUTPUTS
# -------------------------------------------------------------------------
# Internal R object
dir.create(here("data"), showWarnings = FALSE, recursive = TRUE)
saveRDS(grave_d, here("data", "GRAVE_D_Master.rds"))

# CSV exports for consuming repos
dir.create(here("ready_data"), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(grave_d, here("ready_data", "GRAVE_D_Master.csv"))

message(
  "[05_build_master.R] Done. GRAVE_D_Master saved: ",
  nrow(grave_d), " rows x ", ncol(grave_d), " columns."
)
message("  -> data/GRAVE_D_Master.rds")
message("  -> ready_data/GRAVE_D_Master.csv")
