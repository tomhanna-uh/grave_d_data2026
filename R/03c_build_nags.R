# =============================================================================
# 03c_build_nags.R
# Merge Dangerous Companions NAG support (active + de facto) onto GRAVE-D spine.
#
# Non-State Armed Groups and Ideological Signaling:
# Autocratic Use of Non-State Armed Groups as Tools of Revisionist Signaling
# and Autocracy Promotion
#
# This script runs after 03_build_grave_d_ideology.R and before 04_build_controls.R.
# It loads spine_ideology.rds, merges NAG counts/binaries, and saves 
# spine_ideology_nags.rds (so 04 and 05 can pick it up with one tiny change).
#
# Tom Hanna
# University of Houston
# Department of Political Science
# tlhanna@uh.edu
#
# Working manuscript and code repository
# Copyright © Tom Hanna, 2020–2026
# Licensed under CC BY-NC-SA 4.0
# Draft date: March 2026
# =============================================================================

here::i_am("03c_build_nags.R")
source(here::here("R", "00_packages.R"))
message("[03c_build_nags.R] Starting NAG merge onto GRAVE-D spine...")

# ----------------------------------------------------------------------------
# 1. Load NAG active and defacto files (exact delimiter handling)
# ----------------------------------------------------------------------------
active <- read_delim(
        here("source_data", "nags", "dyadic_target_supporter_active.csv"),
        delim = ";", show_col_types = TRUE
)

defact <- read_delim(
        here("source_data", "nags", "dyadic_target_supporter_defact.csv"),
        delim = ";", show_col_types = TRUE
)

# ----------------------------------------------------------------------------
# 2. Combine active + defacto (your successful full_join)
# ----------------------------------------------------------------------------
nags_data <- full_join(active, defact,
                       by = c("TarNum_COW", "SupNum_COW", "Year"))

message(sprintf("[03c] Combined NAG data: %d rows", nrow(nags_data)))

# ----------------------------------------------------------------------------
# 3. Load GRAVE-D spine from script 03 (spine_ideology.rds)
# ----------------------------------------------------------------------------
spine_path <- here("data", "spine_ideology.rds")
if (!file.exists(spine_path)) {
        stop("[03c] spine_ideology.rds not found. Run up to 03_build_grave_d_ideology.R first.")
}
spine <- readRDS(spine_path) |>
        mutate(across(c(COWcode_a, COWcode_b), as.integer))

message(sprintf("[03c] Loaded spine (from script 03): %d rows", nrow(spine)))

# ----------------------------------------------------------------------------
# 4. Join combined nags_data onto the spine
# ----------------------------------------------------------------------------
spine_nags <- spine |>
        left_join(
                nags_data,
                by = c("COWcode_a" = "SupNum_COW",
                       "COWcode_b" = "TarNum_COW",
                       "year"      = "Year")
        )

message(sprintf("[03c] After join: %d rows", nrow(spine_nags)))

# ----------------------------------------------------------------------------
# 5. Build nags_* variables 
#    - COUNT variables = numeric counts (0, 1, 2, ...)
#    - BINARY variables = integer 0/1
# ----------------------------------------------------------------------------
spine_nags <- spine_nags |>
        mutate(
                # Raw count variables (exactly as in the original NAG source data)
                nags_support_count = coalesce(NumNAG_S, NumNAG_DS, 0L),
                
                nags_training   = as.numeric(pmax(Num_S_TrainCamp, Num_S_Training,
                                                  Num_DS_TrainCamp, Num_DS_Training, na.rm = TRUE)),
                
                nags_arms       = as.numeric(pmax(Num_S_WeaponLog, Num_S_Transport,
                                                  Num_DS_WeaponLog, Num_DS_Transport, na.rm = TRUE)),
                
                nags_funds      = as.numeric(pmax(Num_S_FinAid, Num_DS_FinAid, na.rm = TRUE)),
                
                nags_troops     = as.numeric(Num_S_Troop),   # only exists in active file
                
                nags_safe_haven = as.numeric(pmax(Num_S_SafeMem, Num_S_SafeLead,
                                                  Num_DS_SafeMem, Num_DS_SafeLead, na.rm = TRUE)),
                
                # Binary composites (0/1 integer — used in your signaling interactions)
                nags_any_support = if_else(
                        nags_support_count > 0 | nags_training > 0 | nags_arms > 0 |
                                nags_funds > 0 | nags_troops > 0 | nags_safe_haven > 0,
                        1L, 0L
                ),
                
                nags_active_support = as.integer(nags_training > 0 | nags_arms > 0 | 
                                                         nags_funds > 0 | nags_troops > 0),
                
                nags_defacto_support = as.integer(nags_safe_haven > 0)
        ) |>
        # One-pass zero-fill (memory-efficient)
        mutate(across(starts_with("nags_"), ~replace_na(., 0L)))

# ----------------------------------------------------------------------------
# 6. Final diagnostics (counts vs binaries)
# ----------------------------------------------------------------------------
message("[03c] FINAL TYPE + VALUE CHECK — counts are numeric, binaries are 0/1:")
spine_nags |>
        summarise(across(starts_with("nags_"),
                         list(class = ~class(.),
                              max   = ~max(., na.rm = TRUE),
                              mean  = ~mean(., na.rm = TRUE)))) |>
        print()

# ----------------------------------------------------------------------------
# 7. Save updated spine (for 04_build_controls.R and downstream)
# ----------------------------------------------------------------------------
saveRDS(spine_nags, here("data", "spine_ideology_nags.rds"))
message("[03c_build_nags.R] Saved: data/spine_ideology_nags.rds")
message("[03c_build_nags.R] Done.")