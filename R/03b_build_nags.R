# =============================================================================
# 03b_build_nags.R
# Merge Non-State Armed Groups (NAG) support variables from Dangerous Companions
# dyadic target-supporter active and de facto files onto the GRAVE-D spine.
#
# Input: data/spine_controls.rds (from prior step)
# source_data/nags/dyadic_target_supporter_active.csv
# source_data/nags/dyadic_target_supporter_defact.csv
#
# Output: Updated spine with nags_* variables (counts and binaries)
# =============================================================================
source(here::here("R", "00_packages.R"))
message("[03b_build_nags.R] Starting NAG support merge...")

# ----------------------------------------------------------------------------
# 1. Load spine
# ----------------------------------------------------------------------------
spine_path <- here("data", "spine_controls.rds")
if (!file.exists(spine_path)) {
        stop("[03b] spine_controls.rds not found. Run prior steps first.")
}
spine <- readRDS(spine_path) |>
        mutate(across(c(COWcode_a, COWcode_b), as.integer))  # force integer
message(sprintf("[03b] Loaded spine: %d rows", nrow(spine)))


# 1. Exact class/types of keys
message("Spine COWcode_a class:")
class(spine$COWcode_a) |> print()
message("Spine COWcode_b class:")
class(spine$COWcode_b) |> print()
message("Active supnum_cow class:")
class(active$supnum_cow) |> print()
message("Active tarnum_cow class:")
class(active$tarnum_cow) |> print()
message("Active year class:")
class(active$year) |> print()
message("Spine year class:")
class(spine$year) |> print()

# 2. Larger sample of unique COW codes (first 50)
message("Spine COWcode_a unique (first 50):")
sort(unique(spine$COWcode_a)) |> head(50) |> print()

message("Active supnum_cow unique (first 50):")
sort(unique(active$supnum_cow)) |> head(50) |> print()

message("Spine COWcode_b unique (first 50):")
sort(unique(spine$COWcode_b)) |> head(50) |> print()

message("Active tarnum_cow unique (first 50):")
sort(unique(active$tarnum_cow)) |> head(50) |> print()

# 3. Check for any match on supporter alone (ignore target/year for test)
message("Rows with supporter match (COWcode_a = supnum_cow):")
spine |>
        inner_join(active, by = c("COWcode_a" = "supnum_cow")) |>
        nrow() |> print()

message("Rows with target match (COWcode_b = tarnum_cow):")
spine |>
        inner_join(active, by = c("COWcode_b" = "tarnum_cow")) |>
        nrow() |> print()

# 4. After join attempt, check if suffixed columns exist at all
message("Columns after normal join attempt:")
names(spine_nags) |> str_subset("active|defact") |> print()

# ----------------------------------------------------------------------------
# 2. Load NAG dyadic files (semicolon-delimited!)
# ----------------------------------------------------------------------------
active_path <- here("source_data", "nags", "dyadic_target_supporter_active.csv")

# 1. Exact class/types of keys
message("Spine COWcode_a class:")
class(spine$COWcode_a) |> print()
message("Spine COWcode_b class:")
class(spine$COWcode_b) |> print()
message("Active supnum_cow class:")
class(active$supnum_cow) |> print()
message("Active tarnum_cow class:")
class(active$tarnum_cow) |> print()
message("Active year class:")
class(active$year) |> print()
message("Spine year class:")
class(spine$year) |> print()

# 2. Larger sample of unique COW codes (first 50)
message("Spine COWcode_a unique (first 50):")
sort(unique(spine$COWcode_a)) |> head(50) |> print()

message("Active supnum_cow unique (first 50):")
sort(unique(active$supnum_cow)) |> head(50) |> print()

message("Spine COWcode_b unique (first 50):")
sort(unique(spine$COWcode_b)) |> head(50) |> print()

message("Active tarnum_cow unique (first 50):")
sort(unique(active$tarnum_cow)) |> head(50) |> print()

# 3. Check for any match on supporter alone (ignore target/year for test)
message("Rows with supporter match (COWcode_a = supnum_cow):")
spine |>
        inner_join(active, by = c("COWcode_a" = "supnum_cow")) |>
        nrow() |> print()

message("Rows with target match (COWcode_b = tarnum_cow):")
spine |>
        inner_join(active, by = c("COWcode_b" = "tarnum_cow")) |>
        nrow() |> print()

# 4. After join attempt, check if suffixed columns exist at all
message("Columns after normal join attempt:")
names(spine_nags) |> str_subset("active|defact") |> print()


defact_path <- here("source_data", "nags", "dyadic_target_supporter_defact.csv")

# 1. Exact class/types of keys
message("Spine COWcode_a class:")
class(spine$COWcode_a) |> print()
message("Spine COWcode_b class:")
class(spine$COWcode_b) |> print()
message("Active supnum_cow class:")
class(active$supnum_cow) |> print()
message("Active tarnum_cow class:")
class(active$tarnum_cow) |> print()
message("Active year class:")
class(active$year) |> print()
message("Spine year class:")
class(spine$year) |> print()

# 2. Larger sample of unique COW codes (first 50)
message("Spine COWcode_a unique (first 50):")
sort(unique(spine$COWcode_a)) |> head(50) |> print()

message("Active supnum_cow unique (first 50):")
sort(unique(active$supnum_cow)) |> head(50) |> print()

message("Spine COWcode_b unique (first 50):")
sort(unique(spine$COWcode_b)) |> head(50) |> print()

message("Active tarnum_cow unique (first 50):")
sort(unique(active$tarnum_cow)) |> head(50) |> print()

# 3. Check for any match on supporter alone (ignore target/year for test)
message("Rows with supporter match (COWcode_a = supnum_cow):")
spine |>
        inner_join(active, by = c("COWcode_a" = "supnum_cow")) |>
        nrow() |> print()

message("Rows with target match (COWcode_b = tarnum_cow):")
spine |>
        inner_join(active, by = c("COWcode_b" = "tarnum_cow")) |>
        nrow() |> print()

# 4. After join attempt, check if suffixed columns exist at all
message("Columns after normal join attempt:")
names(spine_nags) |> str_subset("active|defact") |> print()


if (!all(file.exists(active_path, defact_path))) {
        stop("[03b] One or both NAG files missing in source_data/nags/")
}

active <- read_delim(active_path, delim = ";", show_col_types = FALSE) |>
        rename_with(tolower) |>
        janitor::clean_names() |>
        mutate(across(c(tarnum_cow, supnum_cow), as.integer))  # force integer

defact <- read_delim(defact_path, delim = ";", show_col_types = FALSE) |>
        rename_with(tolower) |>
        janitor::clean_names() |>
        mutate(across(c(tarnum_cow, supnum_cow), as.integer))

message("[03b] Loaded active NAG support: ", nrow(active), " rows")
message("[03b] Loaded defacto NAG support: ", nrow(defact), " rows")

# ----------------------------------------------------------------------------
# 3. Diagnostics - column names and sample values
# ----------------------------------------------------------------------------
message("[03b] Active NAG columns:")
names(active) |> print()

message("[03b] Defacto NAG columns:")
names(defact) |> print()

message("[03b] Active year range:")
range(active$year, na.rm = TRUE) |> print()

message("[03b] Spine year range:")
range(spine$year, na.rm = TRUE) |> print()

message("[03b] Active supnum_cow sample (supporter):")
sort(unique(active$supnum_cow)) |> head(20) |> print()

message("[03b] Spine COWcode_a sample (supporter):")
sort(unique(spine$COWcode_a)) |> head(20) |> print()

message("[03b] Active tarnum_cow sample (target):")
sort(unique(active$tarnum_cow)) |> head(20) |> print()

message("[03b] Spine COWcode_b sample (target):")
sort(unique(spine$COWcode_b)) |> head(20) |> print()

# ----------------------------------------------------------------------------
# 4. Join attempts
# ----------------------------------------------------------------------------
message("[03b] Trying normal join (supnum_cow = COWcode_a, tarnum_cow = COWcode_b)")
spine_nags <- spine |>
        left_join(active, by = c("COWcode_a" = "supnum_cow", "COWcode_b" = "tarnum_cow", "year" = "year")) |>
        left_join(defact, by = c("COWcode_a" = "supnum_cow", "COWcode_b" = "tarnum_cow", "year" = "year"), suffix = c("_active", "_defact"))

message("[03b] Matches in normal join (rows with numnag_s_active non-NA):")
sum(!is.na(spine_nags$numnag_s_active)) |> print()

message("[03b] Trying reversed join (supnum_cow = COWcode_b, tarnum_cow = COWcode_a)")
spine_rev <- spine |>
        left_join(active, by = c("COWcode_b" = "supnum_cow", "COWcode_a" = "tarnum_cow", "year" = "year")) |>
        left_join(defact, by = c("COWcode_b" = "supnum_cow", "COWcode_a" = "tarnum_cow", "year" = "year"), suffix = c("_active", "_defact"))

message("[03b] Matches in reversed join (rows with numnag_s_active non-NA):")
sum(!is.na(spine_rev$numnag_s_active)) |> print()

# Choose the direction with matches
if (sum(!is.na(spine_nags$numnag_s_active)) > 0) {
        message("[03b] Normal join matched - using it.")
        spine_nags <- spine_nags
} else if (sum(!is.na(spine_rev$numnag_s_active)) > 0) {
        message("[03b] Reversed join matched - using it.")
        spine_nags <- spine_rev
} else {
        stop("[03b] No matches in either join direction. Check COW codes, years, or data overlap.")
}

# ----------------------------------------------------------------------------
# 5. Construct nags_* variables
# ----------------------------------------------------------------------------
spine_nags <- spine_nags |>
        mutate(
                nags_support_count = coalesce(numnag_s_active, numnag_ds_defact, 0L),
                nags_training = pmax(
                        num_s_traincamp_active, num_s_training_active,
                        num_ds_traincamp_defact, num_ds_training_defact,
                        na.rm = TRUE
                ),
                nags_arms = pmax(
                        num_s_weaponlog_active, num_s_transport_active,
                        num_ds_weaponlog_defact, num_ds_transport_defact,
                        na.rm = TRUE
                ),
                nags_funds = pmax(
                        num_s_finaid_active,
                        num_ds_finaid_defact,
                        na.rm = TRUE
                ),
                nags_troops = pmax(
                        num_s_troop_active,
                        num_ds_troop_defact,
                        na.rm = TRUE
                ),
                nags_safe_haven = pmax(
                        num_s_safemem_active, num_s_safelead_active,
                        num_ds_safemem_defact, num_ds_safelead_defact,
                        na.rm = TRUE
                ),
                nags_any_support = if_else(
                        nags_support_count > 0 | nags_training > 0 | nags_arms > 0 |
                                nags_funds > 0 | nags_troops > 0 | nags_safe_haven > 0,
                        1L, 0L
                ),
                nags_active_support = nags_training | nags_arms | nags_funds | nags_troops,
                nags_defacto_support = nags_safe_haven
        ) |>
        mutate(across(starts_with("nags_"), ~replace_na(., 0L)))

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