# =============================================================================
# 03_build_grave_d_ideology.R
# Merge leader-level data from Archigos, Colgan, and Global Leader Ideology
# onto the conflict spine.
#
# This script attaches RAW leader attributes to the spine. The final
# GRAVE-D sidea_* ideology and support-group variables are CONSTRUCTED
# in 04_build_controls.R after V-Dem data is available, because most
# of those variables derive from V-Dem legitimation indicators
# (v2exl_legitideol, v2exl_legitperf, v2exl_legitlead, etc.).
#
# Input: data/spine_conflict.rds (from 02_build_conflict.R)
# source_data/archigos/
# source_data/colgan/
# source_data/leader_ideology/
# Output: data/spine_ideology.rds
# =============================================================================

here::i_am("R/03_build_grave_d_ideology.R")

source(here::here("R", "00_packages.R"))
source(here::here("R", "utils_leaders.R"))
message("[03_build_grave_d_ideology.R] Starting leader data merge...")

# ----------------------------------------------------------------------------- 
# 1. Load spine with conflict
# ----------------------------------------------------------------------------- 
spine_path <- here("data", "spine_conflict.rds")
if (!file.exists(spine_path)) {
        stop("[03] spine_conflict.rds not found.\nRun R/02_build_conflict.R first.")
}
spine <- readRDS(spine_path)
message(sprintf("[03] Loaded spine: %d rows", nrow(spine)))

# ----------------------------------------------------------------------------- 
# 2. Load Archigos leader data
# ----------------------------------------------------------------------------- 
archigos_raw <- load_leader_data(here("source_data", "archigos"), ".*\\.(csv|tsv|dta|xlsx)$", "[03] Archigos")

# ----------------------------------------------------------------------------- 
# 3. Load Colgan leader data
# ----------------------------------------------------------------------------- 
colgan_raw <- load_leader_data(here("source_data", "colgan"), ".*\\.(csv|tsv|dta|xlsx)$", "[03] Colgan")

# ----------------------------------------------------------------------------- 
# 4. Load Global Leader Ideology dataset
# ----------------------------------------------------------------------------- 
ideology_raw <- load_leader_data(here("source_data", "leader_ideology"), ".*\\.(csv|tsv|dta|xlsx)$", "[03] Leader ideology")

# ----------------------------------------------------------------------------- 
# 5. Standardize COW code columns across sources — FIXED for country_code_cow
# ----------------------------------------------------------------------------- 
archigos_raw <- standardize_cowcode(archigos_raw)
colgan_raw   <- standardize_cowcode(colgan_raw)
ideology_raw <- standardize_cowcode(ideology_raw)

# ----------------------------------------------------------------------------- 
# 6. Build leader-year panel and merge onto spine
# ----------------------------------------------------------------------------- 
leader_data <- NULL

# 6a. Archigos: expand to country-year
archigos_cy <- expand_archigos_to_cy(archigos_raw)
if (!is.null(archigos_cy)) {
        leader_data <- archigos_cy
        message(sprintf("[03] Archigos country-year: %d rows", nrow(leader_data)))
}

# 6b. Colgan: merge onto leader_data
if (!is.null(colgan_raw) && !is.null(leader_data)) {
        colgan_join <- intersect(c("COWcode", "year"), names(colgan_raw))
        if (length(colgan_join) == 2) {
                colgan_clean <- colgan_raw |> distinct(COWcode, year, .keep_all = TRUE)
                leader_data <- leader_data |>
                        left_join(colgan_clean, by = c("COWcode", "year"), suffix = c("", "_colgan"))
                message(sprintf("[03] After Colgan merge: %d rows", nrow(leader_data)))
        } else {
                message("[03] Colgan data lacks COWcode+year keys; skipping merge.")
        }
} else if (!is.null(colgan_raw) && is.null(leader_data)) {
        if (all(c("COWcode", "year") %in% names(colgan_raw))) {
                leader_data <- colgan_raw |> distinct(COWcode, year, .keep_all = TRUE)
        }
}

# 6c. Leader ideology: merge onto leader_data
if (!is.null(ideology_raw) && !is.null(leader_data)) {
        ideo_join <- intersect(c("COWcode", "year"), names(ideology_raw))
        if (length(ideo_join) == 2) {
                ideology_clean <- ideology_raw |> distinct(COWcode, year, .keep_all = TRUE)
                leader_data <- leader_data |>
                        left_join(ideology_clean, by = c("COWcode", "year"), suffix = c("", "_ideo"))
                message(sprintf("[03] After ideology merge: %d rows", nrow(leader_data)))
        } else {
                message("[03] Ideology data lacks COWcode+year keys; skipping merge.")
        }
} else if (!is.null(ideology_raw) && is.null(leader_data)) {
        if (all(c("COWcode", "year") %in% names(ideology_raw))) {
                leader_data <- ideology_raw |> distinct(COWcode, year, .keep_all = TRUE)
        }
}

# ----------------------------------------------------------------------------- 
# 7. Merge leader data onto spine (Side A: COWcode_a)
# ----------------------------------------------------------------------------- 
if (!is.null(leader_data)) {
        leader_cols <- setdiff(names(leader_data), c("COWcode", "year"))
        message(sprintf(
                "[03] Merging %d leader columns onto spine (Side A): %s",
                length(leader_cols),
                paste(head(leader_cols, 10), collapse = ", ")
        ))
        
        leader_merge <- leader_data |>
                distinct(COWcode, year, .keep_all = TRUE)
        
        spine_ideology <- spine |>
                left_join(leader_merge, by = c("COWcode_a" = "COWcode", "year" = "year"))
        
        n_matched <- sum(!is.na(spine_ideology[[leader_cols[1]]]), na.rm = TRUE)
        message(sprintf(
                "[03] Leader merge coverage: %d / %d rows matched (%.1f%%)",
                n_matched, nrow(spine_ideology),
                100 * n_matched / nrow(spine_ideology)
        ))
} else {
        warning("[03] No leader data available. spine_ideology = spine_conflict.")
        spine_ideology <- spine
}

# ----------------------------------------------------------------------------- 
# 8. Save
# ----------------------------------------------------------------------------- 
saveRDS(spine_ideology, here("data", "spine_ideology.rds"))
message("[03_build_grave_d_ideology.R] Saved: data/spine_ideology.rds")
message("[03_build_grave_d_ideology.R] Done.")