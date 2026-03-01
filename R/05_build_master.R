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
#       Spine plus MID-based conflict variables.
#   - data/spine_ideology.rds
#       Spine plus leader- and ideology-related variables
#       (Archigos, Colgan leaders, global leader ideology).
#   - data/spine_controls.rds
#       Spine plus alliance, economic, capability, and other controls.
#
# Outputs:
#   - data/GRAVE_D_Master.rds
#       Full merged GRAVE-D dyadic dataset as an R object for internal use.
#   - ready_data/GRAVE_D_Master.csv
#       Core GRAVE-D dyadic dataset for external/consumer repos.
#   - ready_data/GRAVE_D_Master_with_Leaders.csv (optional)
#       GRAVE-D dyadic dataset with expanded leader-level attributes,
#       if exported here rather than in a follow-on script.
#
# Directory documentation:
#   - See data/README.md for details on intermediate .rds objects
#     consumed by this script.
#   - See ready_data/README.md for details on the exported .csv files
#     and how they are intended to be used.
#
# Consuming repositories:
#   - data-2025
#       Treats ready_data/GRAVE_D_Master*.csv as the canonical dyadic
#       GRAVE-D input for further cleaning and analysis.
#   - autocracy_conflict_signaling
#       Uses the same GRAVE-D export as the main analysis dataset for
#       modeling and Quarto documents.
#
# Usage:
#   - Run this script after 00_packages.R and 01-04_* scripts have
#     successfully produced all required .rds intermediates in data/.
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
# spine_ideology was built from spine_conflict, so we start from it
# and add control variables
# -------------------------------------------------------------------------
grave_d <- spine_ideology

# -------------------------------------------------------------------------
# 3. ADD CONTROL VARIABLES
# spine_controls adds V-Dem, CINC, ATOP, WRP, econ controls, and
# derived variables (targets_democracy, cold_war)
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
# Check column availability before mutate (avoids . pronoun issues with |>)
has_islm <- all(c("islmgenpct_a", "islmgenpct_b") %in% names(grave_d))
has_chrst <- all(c("chrstgenpct_a", "chrstgenpct_b") %in% names(grave_d))

grave_d <- grave_d |>
  mutate(
    mid_initiated = if_else(
      !is.na(hihosta) & hihosta >= 2, 1L, 0L
    ),
    islm_dist = if (has_islm) abs(islmgenpct_a - islmgenpct_b) else NA_real_,
    chrst_dist = if (has_chrst) abs(chrstgenpct_a - chrstgenpct_b) else NA_real_
  )

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
  "hihosta", "mid_initiated", "targets_democracy", "cold_war",
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

# Optional: leader-expanded export
# If you want a separate file with extra leader attributes, build it here:
# grave_d_leaders <- grave_d  # add any extra leader vars
# readr::write_csv(grave_d_leaders, here("ready_data", "GRAVE_D_Master_with_Leaders.csv"))

message(
  "[05_build_master.R] Done. GRAVE_D_Master saved: ",
  nrow(grave_d), " rows x ", ncol(grave_d), " columns."
)
message("  -> data/GRAVE_D_Master.rds")
message("  -> ready_data/GRAVE_D_Master.csv")
