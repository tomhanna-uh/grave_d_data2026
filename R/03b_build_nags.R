# =============================================================================
# 03b_build_nags.R
# Merge Dangerous Companions NAGs (Non-State Armed Groups) support data
# onto the FBIC spine as directed dyad-year variables
#
# Input:  data/spine_ideology.rds          (from 03_build_grave_d_ideology.R)
#         source_data/nags/<NAGs CSV/DTA>   (Dangerous Companions NAGs dataset)
# Output: data/spine_nags.rds
#
# Source: San-Akca, Belgin. Dangerous Companions: Cooperation Between States
#   and Nonstate Armed Groups (NAGs). Codebook v. April 2015.
#   https://www.armedgroups.net/
#
# The NAGs dataset is a triad-level time-series: Supporter x NAG x Target x Year.
# Each row records whether a state (Supporter) provides support to a NAG that
# is fighting against a Target state, in a given year.
#
# Key source variables:
#   SupNum_COW  -- COW code of the supporter state
#   TarNum_COW  -- COW code of the target state
#   Year        -- Observation year
#   NAGcode_1   -- Unique NAG identifier
#
# The dataset codes 9 types of active support and 8 types of de facto support
# (all except troops). Active support = intentional state policy;
# de facto support = state becomes facilitator without clear intent
# (e.g., rebels use territory as safe haven without explicit approval).
#
# For integration into the GRAVE-D directed dyad spine, we aggregate from
# triad-year to directed dyad-year (Supporter -> Target, Year):
#   - Does Country A actively support any NAG targeting Country B?
#   - Does Country A provide de facto support to any NAG targeting Country B?
#   - How many NAGs does Country A support against Country B?
#
# Variables built:
#   nags_any_support       -- Binary: any support (active or de facto) in dyad
#   nags_active_support    -- Binary: active/intentional support in dyad
#   nags_defacto_support   -- Binary: de facto support in dyad
#   nags_support_count     -- Count of distinct NAGs supported in dyad
#   nags_safe_haven        -- Binary: safe haven support (members or leaders)
#   nags_training          -- Binary: training camps or training provided
#   nags_arms              -- Binary: weapons/logistics or arms transport
#   nags_funds             -- Binary: financial aid provided
#   nags_troops            -- Binary: troop support provided
#
# NAs are coded to 0 (no support).
# =============================================================================

source(here::here("R", "00_packages.R"))

message("[03b_build_nags.R] Starting NAGs support merge...")

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
# 2. Load NAGs dataset
# -----------------------------------------------------------------------------
# The NAGs dataset may be distributed as CSV, DTA, or Excel.
# Expected location: source_data/nags/
nags_dir <- here("source_data", "nags")

if (!dir.exists(nags_dir)) {
  stop(
    "[03b] NAGs source directory not found.\n",
    "  Create: source_data/nags/ and place the NAGs dataset there.\n",
    "  Download from: https://www.armedgroups.net/"
  )
}

# Search for NAGs data files
nags_files <- list.files(
  nags_dir,
  pattern = "\\.(csv|dta|xlsx?)$",
  full.names = TRUE,
  ignore.case = TRUE
)

if (length(nags_files) == 0) {
  stop(
    "[03b] No data files found in source_data/nags/.\n",
    "  Place NAGs dataset (CSV, DTA, or Excel) there.\n",
    "  Download from: https://www.armedgroups.net/"
  )
}

nags_path <- nags_files[1]
message(sprintf("[03b] Loading NAGs file: %s", basename(nags_path)))

if (grepl("\\.csv$", nags_path, ignore.case = TRUE)) {
  nags_raw <- as_tibble(data.table::fread(file = nags_path))
} else if (grepl("\\.dta$", nags_path, ignore.case = TRUE)) {
  nags_raw <- haven::read_dta(nags_path)
} else if (grepl("\\.xlsx?$", nags_path, ignore.case = TRUE)) {
  nags_raw <- readxl::read_excel(nags_path)
}

message(sprintf("[03b] NAGs raw: %d rows x %d cols", nrow(nags_raw), ncol(nags_raw)))

# -----------------------------------------------------------------------------
# 3. Standardize column names
# -----------------------------------------------------------------------------
# The NAGs codebook uses: SupNum_COW, TarNum_COW, Year, NAGcode_1
# Column names may vary by release version; detect flexibly.
orig_names <- names(nags_raw)
message(sprintf("[03b] Columns: %s", paste(orig_names, collapse = ", ")))

# Standardize to lowercase for matching
nags <- nags_raw |> rename_with(tolower)

# Map key ID columns to standard names
id_map <- c(
  supnum_cow = "COWcode_a",   # Supporter = Side A in directed dyad
  tarnum_cow = "COWcode_b"    # Target = Side B in directed dyad
)

for (src in names(id_map)) {
  if (src %in% names(nags)) {
    nags <- nags |> rename(!!id_map[src] := !!sym(src))
  } else {
    # Try partial match
    match_col <- grep(gsub("_", "", src), gsub("_", "", names(nags)),
                       value = FALSE, ignore.case = TRUE)
    if (length(match_col) > 0) {
      nags <- nags |> rename(!!id_map[src] := !!sym(names(nags)[match_col[1]]))
      message(sprintf("[03b] Mapped '%s' -> '%s'", names(nags)[match_col[1]], id_map[src]))
    } else {
      stop(sprintf("[03b] Cannot find column matching '%s' in NAGs data.", src))
    }
  }
}

# Coerce COW codes to numeric (CSV may read them as character)
nags$COWcode_a <- as.numeric(nags$COWcode_a)
nags$COWcode_b <- as.numeric(nags$COWcode_b)
nags$year <- as.numeric(nags$year)

# Ensure 'year' exists
if (!"year" %in% names(nags)) {
  yr_col <- grep("^year$", names(nags), value = TRUE, ignore.case = TRUE)
  if (length(yr_col) > 0) {
    nags <- nags |> rename(year = !!sym(yr_col[1]))
  } else {
    stop("[03b] Cannot find 'year' column in NAGs data.")
  }
}

# Ensure NAG identifier exists
nag_id_col <- NULL
for (candidate in c("nagcode_1", "nagcode1", "nag_code", "nagid")) {
  if (candidate %in% names(nags)) {
    nag_id_col <- candidate
    break
  }
}
if (is.null(nag_id_col)) {
  nag_col <- grep("nagcode|nag_code|nagid", names(nags), value = TRUE, ignore.case = TRUE)
  if (length(nag_col) > 0) {
    nag_id_col <- nag_col[1]
  } else {
    warning("[03b] Cannot find NAG identifier column. Using row-level aggregation.")
    nags$nag_id_placeholder <- seq_len(nrow(nags))
    nag_id_col <- "nag_id_placeholder"
  }
}
message(sprintf("[03b] NAG ID column: %s", nag_id_col))

message(sprintf(
  "[03b] ID columns found. Unique supporters: %d, targets: %d, NAGs: %d",
  n_distinct(nags$COWcode_a), n_distinct(nags$COWcode_b),
  n_distinct(nags[[nag_id_col]])
))

# -----------------------------------------------------------------------------
# 4. Detect and classify support type columns
# -----------------------------------------------------------------------------
# The NAGs codebook codes 9 support types, each with an active (S_) and
# de facto (D_) variant, plus precision columns (S_Precision_1 through 9).
# Column naming varies by release. We detect support columns dynamically.
#
# Known patterns from the codebook:
#   Active support columns:  s_safehavenmem, s_safehavenlead, s_hq,
#     s_traincamp, s_training, s_weapons, s_financial, s_transport, s_troops
#   De facto support columns: d_safehavenmem, d_safehavenlead, d_hq,
#     d_traincamp, d_training, d_weapons, d_financial, d_transport
#     (no d_troops -- troops always implies active)

# Detect active support columns (prefix s_ but not s_precision)
active_cols <- grep("^s_", names(nags), value = TRUE)
active_cols <- active_cols[!grepl("precision", active_cols, ignore.case = TRUE)]

# Detect de facto support columns (prefix d_)
defacto_cols <- grep("^d_", names(nags), value = TRUE)
defacto_cols <- defacto_cols[!grepl("precision|dyad", defacto_cols, ignore.case = TRUE)]

message(sprintf("[03b] Active support columns (%d): %s",
                length(active_cols), paste(active_cols, collapse = ", ")))
message(sprintf("[03b] De facto support columns (%d): %s",
                length(defacto_cols), paste(defacto_cols, collapse = ", ")))

# Classify support types into thematic groups for aggregation
# Safe haven: any column matching safehaven/safe_haven
# Training: any column matching train
# Arms: any column matching weapon/arms/transport
# Funds: any column matching financ/fund
# Troops: any column matching troop
all_support_cols <- c(active_cols, defacto_cols)

classify_support <- function(cols, pattern) {
  grep(pattern, cols, value = TRUE, ignore.case = TRUE)
}

safe_haven_cols <- classify_support(all_support_cols, "safe.?haven|safehaven")
training_cols   <- classify_support(all_support_cols, "train")
arms_cols       <- classify_support(all_support_cols, "weapon|arms|transport")
funds_cols      <- classify_support(all_support_cols, "financ|fund")
troops_cols     <- classify_support(all_support_cols, "troop")

message(sprintf("[03b] Support type columns detected:"))
message(sprintf("  Safe haven: %s", paste(safe_haven_cols, collapse = ", ")))
message(sprintf("  Training:   %s", paste(training_cols, collapse = ", ")))
message(sprintf("  Arms:       %s", paste(arms_cols, collapse = ", ")))
message(sprintf("  Funds:      %s", paste(funds_cols, collapse = ", ")))
message(sprintf("  Troops:     %s", paste(troops_cols, collapse = ", ")))

# -----------------------------------------------------------------------------
# 5. Build row-level support indicators
# -----------------------------------------------------------------------------
# Helper: returns 1 if any column in 'cols' has value >= 1 for a row
has_any <- function(df, cols) {
  if (length(cols) == 0) return(rep(0L, nrow(df)))
  as.integer(rowSums(df[, cols, drop = FALSE] >= 1, na.rm = TRUE) > 0)
}

nags <- nags |>
  mutate(
    has_active  = has_any(pick(everything()), active_cols),
    has_defacto = has_any(pick(everything()), defacto_cols),
    has_any_support = as.integer(has_active == 1L | has_defacto == 1L),
    has_safe_haven  = has_any(pick(everything()), safe_haven_cols),
    has_training    = has_any(pick(everything()), training_cols),
    has_arms        = has_any(pick(everything()), arms_cols),
    has_funds       = has_any(pick(everything()), funds_cols),
    has_troops      = has_any(pick(everything()), troops_cols)
  )

message(sprintf(
  "[03b] Row-level support: %d rows with any support, %d active, %d de facto",
  sum(nags$has_any_support), sum(nags$has_active), sum(nags$has_defacto)
))

# -----------------------------------------------------------------------------
# 6. Aggregate from triad-year to directed dyad-year
# -----------------------------------------------------------------------------
# For each (Supporter -> Target, Year), aggregate across all NAGs:
#   - Any support? (binary)
#   - Active support? (binary)
#   - De facto support? (binary)
#   - How many distinct NAGs supported? (count)
#   - Any of each support type? (binary)
nags_dyad <- nags |>
  filter(!is.na(COWcode_a), !is.na(COWcode_b), !is.na(year)) |>
  group_by(COWcode_a, COWcode_b, year) |>
  summarise(
    nags_any_support    = as.integer(max(has_any_support, na.rm = TRUE) >= 1L),
    nags_active_support = as.integer(max(has_active, na.rm = TRUE) >= 1L),
    nags_defacto_support = as.integer(max(has_defacto, na.rm = TRUE) >= 1L),
    nags_support_count  = n_distinct(.data[[nag_id_col]]),
    nags_safe_haven     = as.integer(max(has_safe_haven, na.rm = TRUE) >= 1L),
    nags_training       = as.integer(max(has_training, na.rm = TRUE) >= 1L),
    nags_arms           = as.integer(max(has_arms, na.rm = TRUE) >= 1L),
    nags_funds          = as.integer(max(has_funds, na.rm = TRUE) >= 1L),
    nags_troops         = as.integer(max(has_troops, na.rm = TRUE) >= 1L),
    .groups = "drop"
  )

message(sprintf(
  "[03b] Dyad-year aggregation: %d directed dyad-years with NAG support",
  nrow(nags_dyad)
))

# -----------------------------------------------------------------------------
# 7. Left-join onto spine
# -----------------------------------------------------------------------------
# The NAGs data maps directly to the directed dyad spine:
#   Supporter (SupNum_COW) = COWcode_a (sender)
#   Target (TarNum_COW)    = COWcode_b (target)
spine_nags <- spine |>
  left_join(nags_dyad, by = c("COWcode_a", "COWcode_b", "year"))

# -----------------------------------------------------------------------------
# 8. Zero-fill NAs (no support = 0)
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
  mean(spine_nags$nags_support_count[spine_nags$nags_any_support > 0])
))

# -----------------------------------------------------------------------------
# 9. Save
# -----------------------------------------------------------------------------
saveRDS(spine_nags, here("data", "spine_nags.rds"))
message("[03b_build_nags.R] Saved: data/spine_nags.rds")
message("[03b_build_nags.R] Done.")

# Cleanup
rm(nags_raw, nags, nags_dyad, spine)
gc()
