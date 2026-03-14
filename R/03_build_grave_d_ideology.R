# =============================================================================
# 03b_build_nags.R
# Merge Non-State Armed Groups (NAG) support variables from Dangerous Companions
# dyadic target-supporter active and de facto files onto the GRAVE-D spine.
#
# Input: data/spine_controls.rds (or spine from prior step)
# source_data/nags/dyadic_target_supporter_active.csv
# source_data/nags/dyadic_target_supporter_defact.csv
#
# Output: Updated spine with nags_* variables (counts and binaries)
# =============================================================================
source(here::here("R", "00_packages.R"))
message("[03b_build_nags.R] Starting NAG support merge...")

# ----------------------------------------------------------------------------
# 1. Load spine (from prior controls/ideology merge)
# ----------------------------------------------------------------------------
spine_path <- here("data", "spine_controls.rds")  # adjust if your spine has different name
if (!file.exists(spine_path)) {
  stop("[03b] spine_controls.rds not found. Run prior steps first.")
}
spine <- readRDS(spine_path)
message(sprintf("[03b] Loaded spine: %d rows", nrow(spine)))

# ----------------------------------------------------------------------------
# 2. Load NAG dyadic active and de facto files (semicolon-delimited!)
# ----------------------------------------------------------------------------
active_path <- here("source_data", "nags", "dyadic_target_supporter_active.csv")
defact_path <- here("source_data", "nags", "dyadic_target_supporter_defact.csv")

if (!file.exists(active_path) || !file.exists(defact_path)) {
  stop("[03b] One or both NAG files missing in source_data/nags/")
}

active <- read_delim(active_path, delim = ";", show_col_types = FALSE) |>
  rename_with(tolower) |>
  janitor::clean_names()  # optional: extra cleaning

defact <- read_delim(defact_path, delim = ";", show_col_types = FALSE) |>
  rename_with(tolower) |>
  janitor::clean_names()

message("[03b] Loaded active NAG support: ", nrow(active), " rows")
message("[03b] Loaded defacto NAG support: ", nrow(defact), " rows")

# Diagnostic: show actual column names after loading
message("Active NAG columns:")
print(names(active))

message("Defacto NAG columns:")
print(names(defact))

# ----------------------------------------------------------------------------
# 3. Quick raw source diagnostics (should show non-zero variation)
# ----------------------------------------------------------------------------
message("Active NAG raw non-zero counts:")
active |>
  summarise(across(where(is.numeric), list(nonzero = ~sum(. > 0, na.rm = TRUE)))) |>
  print()

message("Defacto NAG raw non-zero counts:")
defact |>
  summarise(across(where(is.numeric), list(nonzero = ~sum(. > 0, na.rm = TRUE)))) |>
  print()

# ----------------------------------------------------------------------------
# 4. Merge onto spine (dyadic-year)
# Assume keys: tarnum_cow = target COW = COWcode_b
#              supnum_cow = supporter COW = COWcode_a
#              year = year
# ----------------------------------------------------------------------------
spine_nags <- spine |>
  left_join(
    active,
    by = c("COWcode_b" = "tarnum_cow", "COWcode_a" = "supnum_cow", "year" = "year")
  ) |>
  left_join(
    defact,
    by = c("COWcode_b" = "tarnum_cow", "COWcode_a" = "supnum_cow", "year" = "year"),
    suffix = c("_active", "_defact")
  )

# ----------------------------------------------------------------------------
# 5. Construct nags_* variables (merge active + defacto)
# ----------------------------------------------------------------------------
spine_nags <- spine_nags |>
  mutate(
    # Count: coalesce active and defacto
    nags_support_count = coalesce(numnag_s_active, numnag_ds_defact, 0L),
    
    # Training (high-visibility)
    nags_training = pmax(
      num_s_traincamp_active, num_s_training_active,
      num_ds_traincamp_defact, num_ds_training_defact,
      na.rm = TRUE
    ),
    
    # Arms/transport
    nags_arms = pmax(
      num_s_weaponlog_active, num_s_transport_active,
      num_ds_weaponlog_defact, num_ds_transport_defact,
      na.rm = TRUE
    ),
    
    # Funds
    nags_funds = pmax(
      num_s_finaid_active,
      num_ds_finaid_defact,
      na.rm = TRUE
    ),
    
    # Troops
    nags_troops = pmax(
      num_s_troop_active,
      num_ds_troop_defact,
      na.rm = TRUE
    ),
    
    # Safe haven
    nags_safe_haven = pmax(
      num_s_safemem_active, num_s_safelead_active,
      num_ds_safemem_defact, num_ds_safelead_defact,
      na.rm = TRUE
    ),
    
    # Any support
    nags_any_support = if_else(
      nags_support_count > 0 | nags_training > 0 | nags_arms > 0 |
      nags_funds > 0 | nags_troops > 0 | nags_safe_haven > 0,
      1L, 0L
    ),
    
    # Active vs de facto split
    nags_active_support = nags_training | nags_arms | nags_funds | nags_troops,
    nags_defacto_support = nags_safe_haven  # adjust if more de facto types
    
  ) |>
  # Zero-fill all nags_* columns for non-matches
  mutate(across(starts_with("nags_"), ~ replace_na(., 0L)))

# ----------------------------------------------------------------------------
# 6. Final diagnostics
# ----------------------------------------------------------------------------
message("[03b] Post-merge NAG variation summary:")
spine_nags |>
  summarise(across(starts_with("nags_"),
                   list(n_missing = ~sum(is.na(.)),
                        nonzero = ~sum(. > 0, na.rm = TRUE),
                        mean = ~mean(., na.rm = TRUE)))) |>
  print()

message("[03b] Rows with any NAG support:")
spine_nags |>
  filter(nags_any_support > 0) |>
  count() |>
  print()

# ----------------------------------------------------------------------------
# 7. Save updated spine
# ----------------------------------------------------------------------------
saveRDS(spine_nags, here("data", "spine_controls_nags.rds"))
message("[03b_build_nags.R] Saved: data/spine_controls_nags.rds")
message("[03b_build_nags.R] Done. Re-run downstream scripts in nags_signaling.")
