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
#   - data/spine_controls.rds (latest with triadic NAGs + V-Dem)
#
# Outputs:
#   - data/GRAVE_D_Master.rds
#   - ready_data/GRAVE_D_Master.csv
#   - ready_data/GRAVE_D_Master_with_Leaders.csv
# =============================================================================
here::i_am("R/05_build_master.R")
source(here::here("R", "00_packages.R"))
message("[05_build_master.R] Assembling GRAVE-D master dataset...")

# -------------------------------------------------------------------------
# 1. LOAD THE LATEST SPINE (contains everything: triadic NAGs + V-Dem + controls)
# -------------------------------------------------------------------------
spine_path <- here("data", "spine_controls.rds")
if (!file.exists(spine_path)) {
        stop("[05] spine_controls.rds not found.\nRun 04_build_controls.R first.")
}
grave_d <- readRDS(spine_path)
message(sprintf("[05] Loaded latest spine_controls.rds: %d rows x %d cols", nrow(grave_d), ncol(grave_d)))

# Quick diagnostic to confirm key groups
message("[05] Checking key variable groups...")
print("V-Dem columns present (first 5):")
print(names(grave_d)[grepl("v2exl_legitideol|v2x_libdem", names(grave_d))][1:5])

print("All nags_* columns present:")
nags_cols <- names(grave_d)[grepl("^nags_", names(grave_d))]
print(nags_cols)

# -------------------------------------------------------------------------
# 2. ADD ANY REMAINING INTERMEDIATES (nonstate, old NAGs) if they exist
# -------------------------------------------------------------------------
nonstate_path <- here("data", "spine_nonstate.rds")
if (file.exists(nonstate_path)) {
        nonstate <- readRDS(nonstate_path)
        grave_d <- grave_d |>
                left_join(nonstate, by = c("COWcode_a", "COWcode_b", "year"))
        message("[05] Added nonstate conflict variables.")
}

nags_path <- here("data", "spine_nags.rds")
if (file.exists(nags_path)) {
        nags <- readRDS(nags_path)
        grave_d <- grave_d |>
                left_join(nags, by = c("COWcode_a", "COWcode_b", "year"))
        message("[05] Added old NAG variables.")
}

# -------------------------------------------------------------------------
# 3. FORCE REVISIONIST POTENTIAL (V-Dem is present in spine_controls)
# -------------------------------------------------------------------------
key_vdem_cols <- c("v2exl_legitideol_a", "v2exl_legitideol_b",
                   "v2x_libdem_a", "v2x_libdem_b")
if (all(key_vdem_cols %in% names(grave_d))) {
        grave_d <- grave_d |>
                group_by(year) |>
                mutate(
                        global_med_ideol = median(v2exl_legitideol_a, na.rm = TRUE),
                        ideol_extremity_a = abs(v2exl_legitideol_a - global_med_ideol),
                        ideol_extremity_b = abs(v2exl_legitideol_b - global_med_ideol)
                ) |>
                ungroup() |>
                mutate(
                        dem_constraint_inv_a = 1 - v2x_libdem_a,
                        dem_constraint_inv_b = 1 - v2x_libdem_b
                ) |>
                mutate(
                        z_legit_a = as.numeric(scale(v2exl_legitideol_a)),
                        z_dem_a = as.numeric(scale(dem_constraint_inv_a)),
                        z_ext_a = as.numeric(scale(ideol_extremity_a)),
                        z_legit_b = as.numeric(scale(v2exl_legitideol_b)),
                        z_dem_b = as.numeric(scale(dem_constraint_inv_b)),
                        z_ext_b = as.numeric(scale(ideol_extremity_b)),
                        rev_potential_a = (z_legit_a + z_dem_a + z_ext_a) / 3,
                        rev_potential_b = (z_legit_b + z_dem_b + z_ext_b) / 3,
                        revisionism_distance = abs(rev_potential_a - rev_potential_b)
                )
        message("Built revisionist_potential variables (rev_potential_a/b, revisionism_distance).")
} else {
        message("V-Dem libdem/legitideol still missing – skipping revisionist_potential.")
}

# -------------------------------------------------------------------------
# 4. Leader-expanded export (using existing colgan_clean in environment)
# -------------------------------------------------------------------------
grave_d_leaders <- grave_d

# Colgan Side A merge (use existing colgan_clean)
if (exists("colgan_clean") && "COWcode" %in% names(colgan_clean)) {
        grave_d_leaders <- grave_d_leaders |>
                left_join(colgan_clean, by = c("COWcode_a" = "COWcode", "year"))
        message("Added Colgan Side A columns from existing colgan_clean.")
} else {
        message("colgan_clean not found or missing COWcode; skipping Side A Colgan merge.")
}

# Colgan Side B merge (use existing colgan_clean)
if (exists("colgan_clean") && "COWcode" %in% names(colgan_clean)) {
        colgan_b <- colgan_clean |>
                rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)) |>
                distinct(COWcode, year, .keep_all = TRUE)
        grave_d_leaders <- grave_d_leaders |>
                left_join(colgan_b, by = c("COWcode_b" = "COWcode", "year"))
        message("Added Colgan Side B columns from existing colgan_clean.")
} else {
        message("colgan_clean not found or missing COWcode; skipping Side B Colgan merge.")
}

# --- Save leader-expanded export ---
readr::write_csv(
        grave_d_leaders,
        here("ready_data", "GRAVE_D_Master_with_Leaders.csv")
)
message(sprintf(
        " -> ready_data/GRAVE_D_Master_with_Leaders.csv (%d rows x %d cols)",
        nrow(grave_d_leaders), ncol(grave_d_leaders)
))


# -----------------------------------------------------------------------------
# Cleanup: resolve .x/.y duplicates for core spine variables
# Treat the original spine versions (.x) as authoritative
# -----------------------------------------------------------------------------
core_spine_vars <- c(
        "dyad", "unregiona", "unregionb",
        "bandwidth", "economicbandwidth", "politicalbandwidth", "securitybandwidth",
        "hihosta", "mid_initiated",
        "iso3a", "iso3b",
        "peace_years", "t", "t2", "t3",
        "Target", "Supporter"  # include the two we already fixed conceptually
)

# Pre-calculate column names and existence for vectorized assignment
grave_d_names <- names(grave_d)
vx_names <- paste0(core_spine_vars, ".x")
vy_names <- paste0(core_spine_vars, ".y")

has_vx <- vx_names %in% grave_d_names
has_vy <- vy_names %in% grave_d_names
has_base <- core_spine_vars %in% grave_d_names

# 1. Assign from .x where .x exists
if (any(has_vx)) {
        cols_to_assign <- core_spine_vars[has_vx]
        src_cols <- vx_names[has_vx]
        grave_d[cols_to_assign] <- grave_d[src_cols]
}

# 2. Fallback to .y where:
#    - base v did not exist initially
#    - vx did not exist
#    - vy does exist
needs_vy <- !has_base & !has_vx & has_vy
if (any(needs_vy)) {
        cols_to_assign_y <- core_spine_vars[needs_vy]
        src_cols_y <- vy_names[needs_vy]
        grave_d[cols_to_assign_y] <- grave_d[src_cols_y]
}

# Drop all leftover .x/.y columns
grave_d <- grave_d |>
        dplyr::select(-tidyselect::matches("\\.x$|\\.y$"))


# -------------------------------------------------------------------------
# 7. SAVE OUTPUTS
# -------------------------------------------------------------------------
dir.create(here("data"), showWarnings = FALSE, recursive = TRUE)
saveRDS(grave_d, here("data", "GRAVE_D_Master.rds"))

dir.create(here("ready_data"), showWarnings = FALSE, recursive = TRUE)
readr::write_csv(grave_d, here("ready_data", "GRAVE_D_Master.csv"))




message(
        "[05_build_master.R] Done. GRAVE_D_Master saved: ",
        nrow(grave_d), " rows x ", ncol(grave_d), " columns."
)
message("  -> data/GRAVE_D_Master.rds")
message("  -> ready_data/GRAVE_D_Master.csv")