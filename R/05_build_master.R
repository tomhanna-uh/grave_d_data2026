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
#   - data/spine_ideology.rds
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
                islm_dist  = if (has_islm)  abs(islmgenpct_a - islmgenpct_b) else NA_real_,
                chrst_dist = if (has_chrst) abs(chrstgenpct_a - chrstgenpct_b) else NA_real_
        )

# -------------------------------------------------------------------------
# 4b. REVISIONIST POTENTIAL (from data-2025/revisionist_potential.R)
# -------------------------------------------------------------------------
# Components:
#   ideol_extremity = abs(v2exl_legitideol - annual global median)
#   dem_constraint_inv = 1 - v2x_libdem
#   rev_potential = mean of z-scores of (legitideol, dem_constraint_inv, ideol_extremity)
#   revisionism_distance = abs(rev_potential_a - rev_potential_b)

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
                        
                        # Final Standardized Revisionist Potential (arithmetic mean of z-scores)
                        rev_potential_a = (z_legit_a + z_dem_a + z_ext_a) / 3,
                        rev_potential_b = (z_legit_b + z_dem_b + z_ext_b) / 3,
                        
                        # Dyadic distance (the revisionist gap)
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
        "COWcode_a", "COWcode_b", "year", "dyad", "unregiona", "unregionb",
        "bandwidth", "economicbandwidth", "politicalbandwidth",
        "securitybandwidth", "socialbandwidth",
        "hihosta", "mid_initiated", "fuf_initiator",
        "targets_democracy", "cold_war",
        "rev_potential_a", "rev_potential_b", "revisionism_distance",
        "sidea_revisionist_domestic", "sidea_nationalist_revisionist_domestic",
        "sidea_socialist_revisionist_domestic", "sidea_religious_revisionist_domestic",
        "sidea_reactionary_revisionist_domestic", "sidea_separatist_revisionist_domestic",
        "sidea_dynamic_leader", "sidea_religious_support", "sidea_party_elite_support"
)

all_cols <- names(grave_d)
front_cols <- intersect(preferred_front, all_cols)
rest_cols  <- setdiff(all_cols, front_cols)
grave_d <- grave_d |> select(all_of(c(front_cols, rest_cols)))

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

        