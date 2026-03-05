# =============================================================================
# 03b_build_nags.R
# Merge Dangerous Companions NAGs (Non-State Armed Groups) support data
# onto the FBIC spine as directed dyad-year variables
#
# Input:  data/spine_ideology.rds          (from 03_build_grave_d_ideology.R)
#         source_data/nags/<Active CSV>     (Dyadic active support dataset)
#         source_data/nags/<Defacto CSV>    (Dyadic de facto support dataset)
# Output: data/spine_nags.rds
#
# Source: San-Akca, Belgin. Dangerous Companions: Cooperation Between States
#   and Nonstate Armed Groups (NAGs). Codebook v. April 2015.
#   https://www.armedgroups.net/
#
# This version uses the DYADIC Target-Supporter datasets (active + defacto)
# from armedgroups.net/data.html rather than the triadic dataset.
# Unit of analysis: Supporter x Target x Year (already directed dyad-year).
# Variables are pre-aggregated counts: NumNAG = total NAGs supported,
# Num_S_SafeMem = count of NAGs given safe haven for members, etc.
#
# Variables built for GRAVE-D:
#   nags_any_support         -- Binary: any support (active or de facto)
#   nags_active_support      -- Binary: any active/intentional support
#   nags_defacto_support     -- Binary: any de facto support
#   nags_support_count       -- Count of distinct NAGs supported (from active)
#   nags_safe_haven          -- Binary: safe haven support
#   nags_training            -- Binary: training camps or training
#   nags_arms                -- Binary: weapons/logistics or arms transport
#   nags_funds               -- Binary: financial aid
#   nags_troops              -- Binary: troop support
#
# NAs are coded to 0 (no support).
# =============================================================================
source(here::here("R", "00_packages.R"))
message("[03b_build_nags.R] Starting NAGs support merge (dyadic version)...")

# -----------------------------------------------------------------------------
# 1. Load spine
# -----------------------------------------------------------------------------
spine_path <- here("data", "spine_ideology.rds")
if (!file.exists(spine_path)) {
  stop(
    "[03b] Spine not found. Run R/03_build_grave_d_ideology.R first.\n",
    "  Expected: data/spine_ideology.rds"
  )
}
spine <- readRDS(spine_path)
message(sprintf("[03b] Loaded spine: %d rows", nrow(spine)))

# -----------------------------------------------------------------------------
# 2. Load NAGs dyadic datasets (Active + Defacto)
# -----------------------------------------------------------------------------
nags_dir <- here("source_data", "nags")
if (!dir.exists(nags_dir)) {
  stop(
    "[03b] NAGs source directory not found.\n",
    "  Create: source_data/nags/ and place the dyadic CSVs there.\n",
    "  Download from: https://www.armedgroups.net/data.html"
  )
}

# Detect active and defacto CSV files
all_csvs <- list.files(nags_dir, pattern = "\\.csv$", full.names = TRUE,
                       ignore.case = TRUE)
if (length(all_csvs) == 0) {
  stop("[03b] No CSV files found in source_data/nags/")
}

# Identify which file is active vs defacto by filename or content
active_file <- NULL
defacto_file <- NULL
for (f in all_csvs) {
  bn <- tolower(basename(f))
  if (grepl("active|activ", bn)) active_file <- f
  if (grepl("defacto|de.?facto", bn)) defacto_file <- f
}

# If filename detection fails, try reading headers
if (is.null(active_file) || is.null(defacto_file)) {
  for (f in all_csvs) {
    hdrs <- tolower(names(data.table::fread(f, nrows = 0)))
    if (any(grepl("^num_s_", hdrs)) && is.null(active_file)) active_file <- f
    if (any(grepl("^num_d_", hdrs)) && is.null(defacto_file)) defacto_file <- f
  }
}

if (is.null(active_file)) stop("[03b] Cannot identify active support CSV in source_data/nags/")
message(sprintf("[03b] Active support file: %s", basename(active_file)))
if (!is.null(defacto_file)) {
  message(sprintf("[03b] Defacto support file: %s", basename(defacto_file)))
} else {
  message("[03b] WARNING: No defacto support CSV found. Defacto variables will be 0.")
}

# Read files
active_raw <- as_tibble(data.table::fread(file = active_file))
message(sprintf("[03b] Active raw: %d rows x %d cols", nrow(active_raw), ncol(active_raw)))
message(sprintf("[03b] Active columns: %s", paste(names(active_raw), collapse = ", ")))

if (!is.null(defacto_file)) {
  defacto_raw <- as_tibble(data.table::fread(file = defacto_file))
  message(sprintf("[03b] Defacto raw: %d rows x %d cols", nrow(defacto_raw), ncol(defacto_raw)))
  message(sprintf("[03b] Defacto columns: %s", paste(names(defacto_raw), collapse = ", ")))
} else {
  defacto_raw <- NULL
}

# -----------------------------------------------------------------------------
# 3. Standardize column names and coerce types
# -----------------------------------------------------------------------------
# Both files share: SupNum_COW (supporter), TarNum_COW (target), Year
# Active has: NumNAG, Num_S_SafeHavenMem, Num_S_SafeHavenLead, Num_S_HQ,
#   Num_S_TrainCamp, Num_S_Training, Num_S_Weapons, Num_S_FinAid,
#   Num_S_Transport, Num_S_Troop
# Defacto has: NumNAG, Num_D_SafeHavenMem, Num_D_SafeHavenLead, Num_D_HQ,
#   Num_D_TrainCamp, Num_D_Training, Num_D_Weapons, Num_D_FinAid,
#   Num_D_Transport

standardize_nags <- function(df, label) {
  df <- df |> rename_with(tolower)
  # Map supporter/target COW codes
  cow_a <- grep("supnum|sup_num|supcow", names(df), value = TRUE, ignore.case = TRUE)
  cow_b <- grep("tarnum|tar_num|tarcow", names(df), value = TRUE, ignore.case = TRUE)
  if (length(cow_a) > 0) df <- df |> rename(COWcode_a = !!sym(cow_a[1]))
  if (length(cow_b) > 0) df <- df |> rename(COWcode_b = !!sym(cow_b[1]))
  # Coerce to numeric
  df$COWcode_a <- as.numeric(df$COWcode_a)
  df$COWcode_b <- as.numeric(df$COWcode_b)
  df$year <- as.numeric(df$year)
  message(sprintf("[03b] %s standardized: %d rows, cols: %s",
                  label, nrow(df), paste(names(df), collapse = ", ")))
  df
}

active <- standardize_nags(active_raw, "Active")
if (!is.null(defacto_raw)) {
  defacto <- standardize_nags(defacto_raw, "Defacto")
} else {
  defacto <- NULL
}

# -----------------------------------------------------------------------------
# 4. Build GRAVE-D variables from dyadic count columns
# -----------------------------------------------------------------------------
# The dyadic datasets use Num_ prefixed count variables.
# We convert counts > 0 to binary indicators for GRAVE-D.
# Column names after tolower: numnag, num_s_safehavenmem, etc.

# Helper: find column matching pattern, return values or 0
get_col <- function(df, pattern) {
  col <- grep(pattern, names(df), value = TRUE, ignore.case = TRUE)
  if (length(col) > 0) return(as.numeric(df[[col[1]]]))
  return(rep(0, nrow(df)))
}

# Active support variables
nags_active_dyad <- active |>
  transmute(
    COWcode_a, COWcode_b, year,
    nags_support_count = pmax(get_col(active, "^numnag$"), 0, na.rm = TRUE),
    nags_active_support = as.integer(nags_support_count > 0),
    nags_safe_haven_active = as.integer(
      get_col(active, "num_s_safehavenmem|num_s_safe.*mem") > 0 |
      get_col(active, "num_s_safehavenlead|num_s_safe.*lead") > 0
    ),
    nags_training_active = as.integer(
      get_col(active, "num_s_traincamp|num_s_train.*camp") > 0 |
      get_col(active, "num_s_training") > 0
    ),
    nags_arms_active = as.integer(
      get_col(active, "num_s_weapon") > 0 |
      get_col(active, "num_s_transport") > 0
    ),
    nags_funds_active = as.integer(
      get_col(active, "num_s_finaid|num_s_fin") > 0
    ),
    nags_troops_active = as.integer(
      get_col(active, "num_s_troop") > 0
    )
  )
message(sprintf("[03b] Active dyad-years with support: %d", sum(nags_active_dyad$nags_active_support)))

# Defacto support variables
if (!is.null(defacto)) {
  nags_defacto_dyad <- defacto |>
    transmute(
      COWcode_a, COWcode_b, year,
      nags_defacto_support = as.integer(
        get_col(defacto, "^numnag$") > 0
      ),
      nags_safe_haven_defacto = as.integer(
        get_col(defacto, "num_d_safehavenmem|num_d_safe.*mem") > 0 |
        get_col(defacto, "num_d_safehavenlead|num_d_safe.*lead") > 0
      ),
      nags_training_defacto = as.integer(
        get_col(defacto, "num_d_traincamp|num_d_train.*camp") > 0 |
        get_col(defacto, "num_d_training") > 0
      ),
      nags_arms_defacto = as.integer(
        get_col(defacto, "num_d_weapon") > 0 |
        get_col(defacto, "num_d_transport") > 0
      ),
      nags_funds_defacto = as.integer(
        get_col(defacto, "num_d_finaid|num_d_fin") > 0
      )
    )
  message(sprintf("[03b] Defacto dyad-years with support: %d",
                  sum(nags_defacto_dyad$nags_defacto_support)))
} else {
  nags_defacto_dyad <- NULL
}

# -----------------------------------------------------------------------------
# 5. Combine active + defacto into final GRAVE-D variables
# -----------------------------------------------------------------------------
if (!is.null(nags_defacto_dyad)) {
  nags_combined <- nags_active_dyad |>
    full_join(nags_defacto_dyad, by = c("COWcode_a", "COWcode_b", "year")) |>
    mutate(
      across(everything(), ~ replace_na(., 0L)),
      nags_any_support = as.integer(nags_active_support > 0 | nags_defacto_support > 0),
      nags_safe_haven = as.integer(nags_safe_haven_active > 0 | nags_safe_haven_defacto > 0),
      nags_training = as.integer(nags_training_active > 0 | nags_training_defacto > 0),
      nags_arms = as.integer(nags_arms_active > 0 | nags_arms_defacto > 0),
      nags_funds = as.integer(nags_funds_active > 0 | nags_funds_defacto > 0),
      nags_troops = as.integer(nags_troops_active > 0)
    ) |>
    select(COWcode_a, COWcode_b, year,
           nags_any_support, nags_active_support, nags_defacto_support,
           nags_support_count,
           nags_safe_haven, nags_training, nags_arms, nags_funds, nags_troops)
} else {
  nags_combined <- nags_active_dyad |>
    mutate(
      nags_any_support = nags_active_support,
      nags_defacto_support = 0L,
      nags_safe_haven = nags_safe_haven_active,
      nags_training = nags_training_active,
      nags_arms = nags_arms_active,
      nags_funds = nags_funds_active,
      nags_troops = nags_troops_active
    ) |>
    select(COWcode_a, COWcode_b, year,
           nags_any_support, nags_active_support, nags_defacto_support,
           nags_support_count,
           nags_safe_haven, nags_training, nags_arms, nags_funds, nags_troops)
}
message(sprintf("[03b] Combined: %d dyad-years | any: %d, active: %d, defacto: %d",
                nrow(nags_combined),
                sum(nags_combined$nags_any_support),
                sum(nags_combined$nags_active_support),
                sum(nags_combined$nags_defacto_support)))

# -----------------------------------------------------------------------------
# 6. Left-join onto spine
# -----------------------------------------------------------------------------
spine_nags <- spine |>
  left_join(nags_combined, by = c("COWcode_a", "COWcode_b", "year"))

# -----------------------------------------------------------------------------
# 7. Zero-fill NAs (no support = 0)
# -----------------------------------------------------------------------------
nags_var_cols <- grep("^nags_", names(spine_nags), value = TRUE)
for (col in nags_var_cols) {
  spine_nags[[col]] <- if_else(is.na(spine_nags[[col]]), 0L, as.integer(spine_nags[[col]]))
}
message(sprintf(
  "[03b] After merge: %d rows | %d dyad-years with any NAG support (%.2f%%)",
  nrow(spine_nags),
  sum(spine_nags$nags_any_support > 0),
  100 * mean(spine_nags$nags_any_support > 0)
))
message(sprintf(
  "  Active: %d | De facto: %d | Mean NAGs per supported dyad-year: %.1f",
  sum(spine_nags$nags_active_support > 0),
  sum(spine_nags$nags_defacto_support > 0),
  if (sum(spine_nags$nags_any_support > 0) > 0)
    mean(spine_nags$nags_support_count[spine_nags$nags_any_support > 0]) else 0
))

# -----------------------------------------------------------------------------
# 8. Save
# -----------------------------------------------------------------------------
saveRDS(spine_nags, here("data", "spine_nags.rds"))
message("[03b_build_nags.R] Saved: data/spine_nags.rds")
message("[03b_build_nags.R] Done.")

# Cleanup
rm(active_raw, active, nags_active_dyad, defacto_raw, defacto,
   nags_defacto_dyad, nags_combined, spine)
gc()
