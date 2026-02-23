# -------------------------------------------------------------------------
# 05_build_master.R
# Assemble the GRAVE-D directed dyadic master dataset
# -------------------------------------------------------------------------
#
# Input files (from output/ directory):
#   spine_conflict.rds    (from 02_build_conflict.R)
#   spine_ideology.rds    (from 03_build_grave_d_ideology.R)
#   spine_controls.rds    (from 04_build_controls.R)
#
# Output:
#   output/GRAVE_D_Master.rds   -- directed dyad-year master dataset
#   output/GRAVE_D_Master.csv   -- CSV copy for sharing
# -------------------------------------------------------------------------

source(here::here("R", "00_packages.R"))
message("[05_build_master.R] Assembling GRAVE-D master dataset...")

# -------------------------------------------------------------------------
# 1. LOAD INTERMEDIATE DATASETS
# -------------------------------------------------------------------------

spine_conflict  <- readRDS(here("output", "spine_conflict.rds"))
spine_ideology  <- readRDS(here("output", "spine_ideology.rds"))
spine_controls  <- readRDS(here("output", "spine_controls.rds"))

message("  Loaded: spine_conflict  (", nrow(spine_conflict),  " rows)")
message("  Loaded: spine_ideology  (", nrow(spine_ideology),  " rows)")
message("  Loaded: spine_controls  (", nrow(spine_controls),  " rows)")

# -------------------------------------------------------------------------
# 2. MERGE CONFLICT & IDEOLOGY
# spine_conflict is already the FBIC dyadic spine + MIDs conflict variables
# spine_ideology extends it with leadership ideology & support groups
# -------------------------------------------------------------------------

# spine_ideology was built from spine_conflict, so we start from it
# and add control variables

grave_d <- spine_ideology

# -------------------------------------------------------------------------
# 3. ADD CONTROL VARIABLES
# spine_controls adds V-Dem, COW CINC, WDI, HHI, religion, and
# derived variables (targeted_democracy, cold_war, revisionist_potential)
# -------------------------------------------------------------------------

# Identify dyad-year key columns
key_cols <- c("COWcode_a", "COWcode_b", "year")

# Columns already present in grave_d to avoid duplication
existing_cols <- names(grave_d)

# Columns from spine_controls to add (exclude keys and duplicates)
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

grave_d <- grave_d |>
  mutate(
    # --- Conflict binary outcome -------------------------------------------
    # mid_initiated is set in 02_build_conflict.R; confirm presence
    mid_initiated = if_else(
      !is.na(hihosta) & hihosta >= 2, 1L, 0L
    ),

    # --- Islamic & Christian distance -------------------------------------
    islm_dist  = if (all(c("islmgenpct_a",  "islmgenpct_b")  %in% names(.))) {
      abs(islmgenpct_a  - islmgenpct_b)
    } else NA_real_,
    chrst_dist = if (all(c("chrstgenpct_a", "chrstgenpct_b") %in% names(.))) {
      abs(chrstgenpct_a - chrstgenpct_b)
    } else NA_real_,

    # --- HHI export gap (sender vulnerability vs. target) -----------------
    hhi_export_gap = if (all(c("hhi_export_a", "hhi_export_b") %in% names(.))) {
      hhi_export_a - hhi_export_b
    } else NA_real_
  )

# -------------------------------------------------------------------------
# 5. ADD UN GEOGRAPHIC REGION LABELS (if not already present)
# -------------------------------------------------------------------------

if (!"unregiona" %in% names(grave_d) && "COWcode_a" %in% names(grave_d)) {
  un_region_map <- data.frame(
    COWcode = c(
      2, 20, 40, 41, 42, 51, 52, 53, 54, 55, 56, 57, 58, 60, 70, 80, 90, 91, 92, 93, 94, 95, 100, 101,
      110, 115, 130, 135, 140, 145, 150, 155, 160, 165, 200, 205, 210, 211, 212, 220, 225, 230, 235,
      240, 245, 255, 260, 265, 267, 269, 270, 275, 290, 300, 305, 310, 315, 316, 317, 325, 327, 338,
      339, 345, 346, 347, 349, 350, 352, 355, 359, 360, 365, 366, 367, 368, 369, 370, 371, 372, 373,
      375, 380, 385, 390, 395, 402, 404, 411, 420, 432, 433, 434, 435, 436, 437, 438, 439, 450, 451,
      452, 461, 471, 475, 481, 482, 483, 484, 490, 500, 501, 510, 516, 517, 520, 522, 530, 531, 540,
      541, 551, 552, 553, 560, 565, 570, 571, 572, 580, 581, 590, 591, 600, 615, 616, 620, 625, 630,
      640, 645, 651, 652, 660, 663, 665, 666, 670, 678, 680, 690, 692, 694, 696, 698, 700, 701, 703,
      704, 705, 706, 710, 711, 712, 713, 714, 720, 730, 731, 732, 740, 750, 760, 770, 771, 775, 780,
      781, 790, 800, 811, 812, 816, 817, 820, 830, 840, 850, 900, 910, 920, 940, 950, 970, 983, 986, 990
    ),
    unregion = "Other"
  )
  # Simplified: attach via countrycode if available
  if (requireNamespace("countrycode", quietly = TRUE)) {
    grave_d <- grave_d |>
      mutate(
        unregiona = countrycode::countrycode(COWcode_a, "cown", "un.region.name",
                                             warn = FALSE),
        unregionb = countrycode::countrycode(COWcode_b, "cown", "un.region.name",
                                             warn = FALSE)
      )
    message("  Added unregiona/unregionb via countrycode package.")
  }
}

# -------------------------------------------------------------------------
# 6. CLEAN UP AND STANDARDISE COLUMN ORDER
# -------------------------------------------------------------------------

# Define preferred column order (keys first, then outcomes, then controls)
preferred_front <- c(
  "COWcode_a", "COWcode_b", "year",
  "unregiona", "unregionb",
  # Spine / bandwidth
  "bandwidth", "economicbandwidth", "politicalbandwidth",
  "securitybandwidth", "socialbandwidth",
  # Conflict outcomes
  "hihosta", "mid_initiated", "fatality",
  "targeted_democracy", "cold_war",
  # Ideology & Support
  "sidea_revisionist_domestic", "sidea_nationalist_revisionist_domestic",
  "sidea_socialist_revisionist_domestic", "sidea_religious_revisionist_domestic",
  "sidea_reactionary_revisionist_domestic", "sidea_separatist_revisionist_domestic",
  "sidea_dynamic_leader",
  "sidea_religious_support", "sidea_party_elite_support",
  "revisionist_potential"
)

# Reorder columns: preferred front + everything else
all_cols   <- names(grave_d)
front_cols <- intersect(preferred_front, all_cols)
rest_cols  <- setdiff(all_cols, front_cols)
grave_d    <- grave_d |> select(all_of(c(front_cols, rest_cols)))

# -------------------------------------------------------------------------
# 7. SAVE OUTPUTS
# -------------------------------------------------------------------------

dir.create(here("output"), showWarnings = FALSE, recursive = TRUE)

saveRDS(grave_d, here("output", "GRAVE_D_Master.rds"))
readr::write_csv(grave_d, here("output", "GRAVE_D_Master.csv"))

message(
  "[05_build_master.R] Done. GRAVE_D_Master saved: ",
  nrow(grave_d), " rows x ", ncol(grave_d), " columns."
)
