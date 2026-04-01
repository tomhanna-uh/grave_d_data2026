# =============================================================================
# 06_impute_controls.R
# Targeted imputation for scattered missing data in GRAVE-D
#
# Strategy:
#   1. Identify variables eligible for imputation (continuous/ordinal V-Dem
#      and economic controls with moderate missingness).
#   2. EXCLUDE from imputation:
#      - Structural identifiers (COWcode, year, dyad, iso3, obsid, etc.)
#      - Leader-level variables (Archigos, Colgan) — structurally missing
#        for dyads outside those datasets' coverage
#      - Colgan chg_* variables — only coded for revolutionary leaders
#      - Variables with >80% missing — insufficient data for reliable imputation
#      - Character/text variables
#      - Internet censorship (v2mecenefi) — structurally absent pre-internet
#   3. For eligible variables, apply country-level linear interpolation
#      (within-country, across years) + LOCF/NOCB at edges.
#   4. For any remaining gaps in key analysis variables, apply cross-sectional
#      regional-year median fill as a last resort.
#   5. Recompute derived variables (rev_potential, targets_democracy, etc.)
#      from the imputed base variables.
#
# This script runs AFTER 05_build_master.R and operates on the final
# GRAVE_D_Master.rds object.
# =============================================================================
source(here::here("R", "00_packages.R"))

message("[06_impute_controls.R] Starting targeted imputation...")

grave_d <- readRDS(here("data", "GRAVE_D_Master.rds"))
n_total <- nrow(grave_d)
message(sprintf("  Loaded GRAVE_D_Master: %d rows x %d cols", n_total, ncol(grave_d)))

# -------------------------------------------------------------------------
# 1. DEFINE VARIABLE CATEGORIES
# -------------------------------------------------------------------------

# Variables that should NEVER be imputed
never_impute <- c(
        
        # Identifiers and keys
        "COWcode_a", "COWcode_b", "year", "dyad", "iso3a", "iso3b",
        "unregiona", "unregionb",
        # FBIC spine (complete)
        "bandwidth", "economicbandwidth", "politicalbandwidth", "securitybandwidth",
        # Conflict outcomes (complete or structurally defined)
        "hihosta", "mid_initiated", "cold_war",
        # Temporal controls (complete)
        "peace_years", "t", "t2", "t3", "global_med_ideol",
        # All Archigos variables (leader-spell: structurally missing for non-covered dyads)
        "obsid", "leadid", "idacr", "leader", "startdate", "enddate",
        "entry", "exit", "exitcode", "prevtimesinoffice", "posttenurefate",
        "gender", "yrborn", "yrdied", "borndate", "deathdate", "dbpedia.uri",
        "num.entry", "num.exit", "num.exitcode", "num.posttenurefate",
        # All Colgan variables (structurally missing outside Colgan coverage)
        "fties", "ftcur", "stabb", "onsets", "revonsets", "sideaonsets",
        "force_onsets", "force_revonsets", "force_sideaonsets",
        "obsid_colgan", "ccname", "leader_colgan",
        "startdate_colgan", "enddate_colgan", "entry_colgan",
        "prevtimesinoffice_colgan", "posttenurefate_colgan", "gender_colgan",
        "age0", "startobs", "endobs", "age", "numld",
        "usedforce", "irregulartransition", "foundingleader", "foreigninstall",
        "radicalideology", "democratizing", "revolutionaryleader", "ambiguouscoding",
        "chg_executivepower", "chg_politicalideology", "chg_nameofcountry",
        "chg_propertyowernship", "chg_womenandethnicstatus",
        "chg_religioningovernment", "chg_revolutionarycommittee",
        "totalcategorieschanged", "revage", "radrestrict",
        "start_year", "code", "region", "uniqtag", "coldwar",
        "oecd", "majorpower", "state_num", "regnum",
        "tenure", "peaceyears", "entcat", "entrc", "entrcage", "entrc15",
        "revstart", "durrc", "durrcage", "durrc15", "dem",
        "seveninstitutionscoded", "nonrevonsets",
        # All Side B leader variables
        grep("_b$", names(grave_d), value = TRUE) |>
                (\(x) x[grepl("^(obsid|leadid|idacr|leader|startdate|enddate|entry|exit|exitcode|prevtimesinoffice|posttenurefate|gender|yrborn|yrdied|borndate|deathdate|dbpedia|num\\.|obsid_colgan|ccname|leader_colgan|startdate_colgan|enddate_colgan|entry_colgan|prevtimesinoffice_colgan|posttenurefate_colgan|gender_colgan|stabb|age0|startobs|endobs|age|numld|onsets|revonsets|sideaonsets|force_onsets|force_revonsets|force_sideaonsets|nonrevonsets|usedforce|irregulartransition|foundingleader|foreigninstall|radicalideology|democratizing|revolutionaryleader|ambiguouscoding|chg_|totalcategorieschanged|revage|radrestrict)", x)])(),
        # ATOP identifiers (not alliance indicators — those are already 0-filled)
        "ddyad", "transyr", "version", "atopid1", "atopid2", "atopid3",
        "atopid4", "atopid5", "atopid6", "atopid7",
        # Internet censorship — structurally absent pre-internet era
        "v2mecenefi_a", "v2mecenefi_b",
        # Derived variables — will be recomputed from imputed base variables
        "targets_democracy", "rev_potential_a", "rev_potential_b",
        "revisionism_distance", "ideol_extremity_a", "ideol_extremity_b",
        "dem_constraint_inv_a", "dem_constraint_inv_b",
        "z_legit_a", "z_dem_a", "z_ext_a", "z_legit_b", "z_dem_b", "z_ext_b",
        "islm_dist", "chrst_dist",
        "sidea_revisionist_domestic", "sidea_nationalist_revisionist_domestic",
        "sidea_socialist_revisionist_domestic", "sidea_religious_revisionist_domestic",
        "sidea_reactionary_revisionist_domestic", "sidea_separatist_revisionist_domestic",
        "sidea_dynamic_leader", "sidea_religious_support", "sidea_military_support",
        "sidea_party_elite_support", "sidea_ethnic_racial_support",
        "sidea_rural_worker_support", "sidea_winning_coalition_size",
        
        # UCDP Non-State Conflict variables (absence = 0, not missing)
        "nonstate_conflict_a", "nonstate_conflict_b",
        "nonstate_conflict_count_a", "nonstate_conflict_count_b",
        "nonstate_fatalities_best_a", "nonstate_fatalities_best_b",
        "nonstate_fatalities_low_a", "nonstate_fatalities_low_b",
        "nonstate_fatalities_high_a", "nonstate_fatalities_high_b",

        # NAGs support variables (absence = 0, not missing)
        "nags_any_support", "nags_active_support", "nags_defacto_support",
        "nags_support_count",
        "nags_safe_haven", "nags_training", "nags_arms", "nags_funds", "nags_troops"
)

never_impute <- unique(never_impute)

# Identify numeric columns eligible for imputation
all_numeric <- names(grave_d)[sapply(grave_d, is.numeric)]
eligible <- setdiff(all_numeric, never_impute)

# Further filter: only impute variables with <80% missing
# (variables with >80% missing lack sufficient data for reliable imputation)
na_pcts <- colSums(is.na(grave_d[, eligible, drop = FALSE])) / n_total
eligible <- eligible[na_pcts < 0.80 & na_pcts > 0]

message(sprintf("  %d variables eligible for imputation (numeric, <80%% missing, not excluded).",
                length(eligible)))

# -------------------------------------------------------------------------
# 2. EXTRACT MONADIC PANELS AND INTERPOLATE
# -------------------------------------------------------------------------
# V-Dem and other monadic variables are duplicated across _a and _b.
# We impute at the monadic level to avoid inconsistencies.

# Split eligible vars into Side A stems and Side B stems
side_a_vars <- eligible[grepl("_a$", eligible)]
side_b_vars <- eligible[grepl("_b$", eligible)]
nosuffix_vars <- eligible[!grepl("_(a|b)$", eligible)]

# Load imputation utilities
source(here::here("R", "utils_imputation.R"))

# --- Side A monadic imputation ---
if (length(side_a_vars) > 0) {
        message("  Imputing Side A monadic variables via country-year interpolation...")
        # Extract unique country-year panel for Side A
        panel_a <- grave_d |>
                select(COWcode_a, year, all_of(side_a_vars)) |>
                distinct(COWcode_a, year, .keep_all = TRUE)
        
        before_na <- sum(is.na(panel_a[, side_a_vars]))
        panel_a <- impute_country_panel(panel_a, side_a_vars, "COWcode_a")
        after_na <- sum(is.na(panel_a[, side_a_vars]))
        message(sprintf("    Side A: %d NAs -> %d NAs (filled %d)",
                        before_na, after_na, before_na - after_na))
        
        # Merge back
        grave_d <- grave_d |>
                select(-all_of(side_a_vars)) |>
                left_join(panel_a, by = c("COWcode_a", "year"))
}

# --- Side B monadic imputation ---
if (length(side_b_vars) > 0) {
        message("  Imputing Side B monadic variables via country-year interpolation...")
        panel_b <- grave_d |>
                select(COWcode_b, year, all_of(side_b_vars)) |>
                distinct(COWcode_b, year, .keep_all = TRUE)
        
        before_na <- sum(is.na(panel_b[, side_b_vars]))
        panel_b <- impute_country_panel(panel_b, side_b_vars, "COWcode_b")
        after_na <- sum(is.na(panel_b[, side_b_vars]))
        message(sprintf("    Side B: %d NAs -> %d NAs (filled %d)",
                        before_na, after_na, before_na - after_na))
        
        grave_d <- grave_d |>
                select(-all_of(side_b_vars)) |>
                left_join(panel_b, by = c("COWcode_b", "year"))
}

# --- Non-suffixed variables (e.g., cinc from leader_ideology, polity) ---
if (length(nosuffix_vars) > 0) {
        message(sprintf("  %d non-suffixed variables — skipping (mostly leader-level or Polity).",
                        length(nosuffix_vars)))
        # These are mostly from leader_ideology and are structurally tied to
        # Colgan/leader coverage. Do not impute.
}

# -------------------------------------------------------------------------
# 3. REGIONAL-YEAR MEDIAN FILL (last resort for key analysis variables)
# -------------------------------------------------------------------------
# For countries with NO V-Dem data at all (e.g., microstates), fill
# from the regional-year median. Only applied to core V-Dem indices.

key_vdem_a <- intersect(c(
        "v2x_polyarchy_a", "v2x_libdem_a", "v2x_corr_a", "v2x_rule_a",
        "v2exl_legitideol_a", "v2exl_legitlead_a",
        "v2x_cspart_a", "v2pepwrses_a", "v2pepwrsoc_a", "v2dlreason_a",
        "v2exl_legitideolcr_0_a", "v2exl_legitideolcr_1_a",
        "v2exl_legitideolcr_2_a", "v2exl_legitideolcr_3_a",
        "v2exl_legitideolcr_4_a", "cinc_a"
), names(grave_d))

key_vdem_b <- gsub("_a$", "_b", key_vdem_a)
key_vdem_b <- intersect(key_vdem_b, names(grave_d))

if (length(key_vdem_a) > 0 && "unregiona" %in% names(grave_d)) {
        before_na <- sum(is.na(grave_d[, key_vdem_a]))
        grave_d <- grave_d |>
                group_by(unregiona, year) |>
                mutate(across(all_of(key_vdem_a), ~ if_else(is.na(.), median(., na.rm = TRUE), .))) |>
                ungroup()
        after_na <- sum(is.na(grave_d[, key_vdem_a]))
        message(sprintf("  Regional median fill (Side A): %d NAs -> %d NAs", before_na, after_na))
}

if (length(key_vdem_b) > 0 && "unregionb" %in% names(grave_d)) {
        before_na <- sum(is.na(grave_d[, key_vdem_b]))
        grave_d <- grave_d |>
                group_by(unregionb, year) |>
                mutate(across(all_of(key_vdem_b), ~ if_else(is.na(.), median(., na.rm = TRUE), .))) |>
                ungroup()
        after_na <- sum(is.na(grave_d[, key_vdem_b]))
        message(sprintf("  Regional median fill (Side B): %d NAs -> %d NAs", before_na, after_na))
}

# -------------------------------------------------------------------------
# -------------------------------------------------------------------------
# 4. RECOMPUTE DERIVED VARIABLES FROM IMPUTED BASE VARIABLES
# -------------------------------------------------------------------------
message("  Recomputing derived variables from imputed base data...")

# 4a. Ideology sub-types
if ("v2exl_legitideol_a" %in% names(grave_d)) {
        grave_d <- grave_d |>
                mutate(
                        sidea_revisionist_domestic = v2exl_legitideol_a,
                        sidea_nationalist_revisionist_domestic = if ("v2exl_legitideolcr_0_a" %in% names(grave_d)) v2exl_legitideolcr_0_a else NA_real_,
                        sidea_socialist_revisionist_domestic   = if ("v2exl_legitideolcr_1_a" %in% names(grave_d)) v2exl_legitideolcr_1_a else NA_real_,
                        sidea_reactionary_revisionist_domestic = if ("v2exl_legitideolcr_2_a" %in% names(grave_d)) v2exl_legitideolcr_2_a else NA_real_,
                        sidea_separatist_revisionist_domestic  = if ("v2exl_legitideolcr_3_a" %in% names(grave_d)) v2exl_legitideolcr_3_a else NA_real_,
                        sidea_religious_revisionist_domestic   = if ("v2exl_legitideolcr_4_a" %in% names(grave_d)) v2exl_legitideolcr_4_a else NA_real_,
                        sidea_dynamic_leader = v2exl_legitlead_a
                )
}

# 4b. Support coalition
if ("v2pepwrses_a" %in% names(grave_d)) {
        grave_d <- grave_d |>
                mutate(
                        sidea_party_elite_support    = v2pepwrses_a,
                        sidea_ethnic_racial_support  = v2pepwrsoc_a,
                        sidea_rural_worker_support   = v2x_cspart_a,
                        sidea_military_support       = if ("cinc_a" %in% names(grave_d)) cinc_a else NA_real_,
                        sidea_religious_support      = if ("v2regsupgroups_7_a" %in% names(grave_d)) v2regsupgroups_7_a else NA_real_,
                        sidea_winning_coalition_size = v2dlreason_a
                )
}

# 4c. Targets democracy (autocracy targeting democracy)
if (all(c("v2x_libdem_a", "v2x_libdem_b") %in% names(grave_d))) {
        grave_d <- grave_d |>
                mutate(
                        targets_democracy = if_else(
                                !is.na(v2x_libdem_b) & !is.na(v2x_libdem_a) &
                                        v2x_libdem_b >= 0.5 & v2x_libdem_a < 0.3,
                                1L, 0L
                        )
                )
}

# 4d. Revisionist potential (full recompute)
if (all(c("v2exl_legitideol_a", "v2exl_legitideol_b",
          "v2x_libdem_a", "v2x_libdem_b") %in% names(grave_d))) {
        
        # Ideological extremity
        grave_d <- grave_d |>
                group_by(year) |>
                mutate(
                        global_med_ideol  = median(v2exl_legitideol_a, na.rm = TRUE),
                        ideol_extremity_a = abs(v2exl_legitideol_a - global_med_ideol),
                        ideol_extremity_b = abs(v2exl_legitideol_b - global_med_ideol)
                ) |>
                ungroup()
        
        # Inverted democratic constraint
        grave_d <- grave_d |>
                mutate(
                        dem_constraint_inv_a = 1 - v2x_libdem_a,
                        dem_constraint_inv_b = 1 - v2x_libdem_b
                )
        
        # Z-score standardization and composite
        grave_d <- grave_d |>
                mutate(
                        z_legit_a = as.numeric(scale(v2exl_legitideol_a)),
                        z_dem_a   = as.numeric(scale(dem_constraint_inv_a)),
                        z_ext_a   = as.numeric(scale(ideol_extremity_a)),
                        z_legit_b = as.numeric(scale(v2exl_legitideol_b)),
                        z_dem_b   = as.numeric(scale(dem_constraint_inv_b)),
                        z_ext_b   = as.numeric(scale(ideol_extremity_b)),
                        rev_potential_a      = (z_legit_a + z_dem_a + z_ext_a) / 3,
                        rev_potential_b      = (z_legit_b + z_dem_b + z_ext_b) / 3,
                        revisionism_distance = abs(rev_potential_a - rev_potential_b)
                )
        message("  Recomputed revisionist_potential variables.")
}

# 4e. Religious distances
has_islm  <- all(c("islmgenpct_a", "islmgenpct_b") %in% names(grave_d))
has_chrst <- all(c("chrstgenpct_a", "chrstgenpct_b") %in% names(grave_d))

if (has_islm || has_chrst) {
        grave_d <- grave_d |>
                mutate(
                        islm_dist  = if (has_islm)  abs(islmgenpct_a - islmgenpct_b) else NA_real_,
                        chrst_dist = if (has_chrst) abs(chrstgenpct_a - chrstgenpct_b) else NA_real_
                )
        message("  Recomputed religious distance variables.")
}

# -------------------------------------------------------------------------
# 5. SAVE IMPUTED OUTPUTS
# -------------------------------------------------------------------------
saveRDS(grave_d, here("data", "GRAVE_D_Master.rds"))
readr::write_csv(grave_d, here("ready_data", "GRAVE_D_Master.csv"))

message(sprintf(
        "[06_impute_controls.R] Done. %d rows x %d cols.",
        nrow(grave_d), ncol(grave_d)
))
message("  -> data/GRAVE_D_Master.rds")
message("  -> ready_data/GRAVE_D_Master.csv")

# Print summary of remaining NAs for key analysis variables
key_check <- intersect(c(
        "v2x_libdem_a", "v2x_libdem_b", "v2exl_legitideol_a", "v2exl_legitideol_b",
        "cinc_a", "cinc_b", "rev_potential_a", "rev_potential_b",
        "revisionism_distance", "targets_democracy",
        "sidea_revisionist_domestic", "sidea_nationalist_revisionist_domestic",
        "sidea_military_support", "sidea_religious_support",
        "chrstgenpct_a", "islmgenpct_a", "islm_dist", "chrst_dist"
), names(grave_d))

na_remaining <- colSums(is.na(grave_d[, key_check]))
message("\n  Remaining NAs in key analysis variables:")
for (v in names(na_remaining)) {
        message(sprintf("    %-45s %8d  (%4.1f%%)", v, na_remaining[v],
                        100 * na_remaining[v] / n_total))
}


# -------------------------------------------------------------------------
# 6. RE-EXPORT GRAVE_D_Master_with_Leaders.csv
# -------------------------------------------------------------------------
# The with_Leaders export includes Side B leader data (Archigos + Colgan).
# It must be regenerated after imputation so that the imputed base variables
# are consistent with the leader-merged version.

message("[06] Re-exporting GRAVE_D_Master_with_Leaders.csv from imputed data...")

grave_d_leaders <- grave_d

# --- Archigos Side B ---
archigos_path <- list.files(
        here("source_data", "archigos"),
        pattern = "archigos\\.tsv$", full.names = TRUE, ignore.case = TRUE
)

if (length(archigos_path) > 0) {
        archigos <- as_tibble(data.table::fread(archigos_path[1])) |>
                rename_with(tolower)
        if ("ccode"   %in% names(archigos)) archigos <- archigos |> rename(COWcode = ccode)
        if ("cowcode" %in% names(archigos)) archigos <- archigos |> rename(COWcode = cowcode)
        
        archigos <- archigos |>
                mutate(
                        start_yr = as.integer(format(as.Date(startdate), "%Y")),
                        end_yr   = as.integer(format(as.Date(enddate), "%Y"))
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
                        "obsid", "leadid", "idacr", "leader",
                        "startdate", "enddate", "entry", "exit", "exitcode",
                        "prevtimesinoffice", "posttenurefate", "gender",
                        "yrborn", "yrdied", "borndate", "deathdate", "dbpedia.uri",
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
        pattern = ".*\\.(csv|dta)$", full.names = TRUE, ignore.case = TRUE
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
                        "startdate_colgan", "enddate_colgan",
                        "entry_colgan", "prevtimesinoffice_colgan",
                        "posttenurefate_colgan", "gender_colgan",
                        "fties", "ftcur", "stabb",
                        "age0", "startobs", "endobs", "age", "numld",
                        "onsets", "revonsets", "sideaonsets",
                        "force_onsets", "force_revonsets", "force_sideaonsets",
                        "nonrevonsets",
                        "usedforce", "irregulartransition", "foundingleader",
                        "foreigninstall", "radicalideology", "democratizing",
                        "revolutionaryleader", "ambiguouscoding",
                        "chg_executivepower", "chg_politicalideology",
                        "chg_nameofcountry", "chg_propertyowernship",
                        "chg_womenandethnicstatus", "chg_religioningovernment",
                        "chg_revolutionarycommittee", "totalcategorieschanged",
                        "revage", "radrestrict"
                ))) |>
                rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)) |>
                distinct(COWcode, year, .keep_all = TRUE)
        
        grave_d_leaders <- grave_d_leaders |>
                left_join(colgan_b, by = c("COWcode_b" = "COWcode", "year"))
        
        message(sprintf("  Added %d Colgan Side B columns.", ncol(colgan_b) - 2))
} else {
        message("  Colgan file not found; skipping Side B Colgan merge.")
}

# --- Save with_Leaders export ---
readr::write_csv(
        grave_d_leaders,
        here("ready_data", "GRAVE_D_Master_with_Leaders.csv")
)

message(sprintf(
        "  -> ready_data/GRAVE_D_Master_with_Leaders.csv (%d rows x %d cols)",
        nrow(grave_d_leaders), ncol(grave_d_leaders)
))
message("[06_impute_controls.R] All exports complete.")
