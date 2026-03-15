# =============================================================================
# 03c_build_nags.R
# Merge the combined NAG active + defacto data onto the GRAVE-D spine.
# =============================================================================
here::i_am("03c_build_nags.R")
source(here::here("R", "00_packages.R"))
message("[03c_build_nags.R] Starting NAG merge onto GRAVE-D spine...")

# ----------------------------------------------------------------------------
# 1. Load NAG active and defacto files (your exact code)
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
# 2. Combine active + defacto (your full_join — keeps every row)
# ----------------------------------------------------------------------------
nags_data <- full_join(active, defact, by = c("TarNum_COW", "SupNum_COW", "Year"))

message(sprintf("[03c] Combined NAG data: %d rows", nrow(nags_data)))

# ----------------------------------------------------------------------------
# 3. Load GRAVE-D spine (from 04_build_controls.R)
# ----------------------------------------------------------------------------
spine_path <- here("data", "spine_controls.rds")
if (!file.exists(spine_path)) {
        stop("[03c] spine_controls.rds not found. Run up to 04_build_controls.R first.")
}
spine <- readRDS(spine_path) |>
        mutate(across(c(COWcode_a, COWcode_b), as.integer))

message(sprintf("[03c] Loaded spine: %d rows", nrow(spine)))

# ----------------------------------------------------------------------------
# 4. Join combined nags_data onto the spine (correct keys)
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
# ----------------------------------------------------------------------------
# 5. Build nags_* variables 
#    - COUNT variables (nags_training, nags_arms, nags_funds, nags_troops, nags_safe_haven) = numeric counts (0, 1, 2, ...)
#    - BINARY variables (nags_any_support, nags_active_support, nags_defacto_support) = 0/1 integer
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

message("[03c] FINAL TYPE + VALUE CHECK — counts are numeric, binaries are 0/1:")
spine_nags |>
        summarise(across(starts_with("nags_"),
                         list(class = ~class(.),
                              max   = ~max(., na.rm = TRUE),
                              mean  = ~mean(., na.rm = TRUE)))) |>
        print()

# ----------------------------------------------------------------------------
# 6. Final diagnostics
# ----------------------------------------------------------------------------
message("[03c] Post-merge NAG variation summary:")
spine_nags |>
        summarise(across(starts_with("nags_"),
                         list(nonzero = ~sum(. > 0, na.rm = TRUE),
                              mean   = ~mean(., na.rm = TRUE)))) |>
        print()

message("[03c] Rows with any NAG support:")
spine_nags |>
        filter(nags_any_support > 0) |>
        count() |>
        print()

# ----------------------------------------------------------------------------
# 7. Save updated spine (for 05_build_master.R)
# ----------------------------------------------------------------------------
saveRDS(spine_nags, here("data", "spine_controls_nags.rds"))
message("[03c_build_nags.R] Saved: data/spine_controls_nags.rds")
message("[03c_build_nags.R] Done. Re-run 05_build_master.R and your nags_signaling pipeline.")