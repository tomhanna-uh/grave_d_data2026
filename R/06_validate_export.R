# -------------------------------------------------------------------------
# 06_validate_export.R
# Validate the assembled GRAVE-D master dataset and export final CSVs
# -------------------------------------------------------------------------
#
# Input files (from output/ directory):
#   GRAVE_D_Master.rds    (from 05_build_master.R)
#
# Output:
#   ready_data/GRAVE_D_Master.csv
#   ready_data/GRAVE_D_Master_with_Leaders.csv
# -------------------------------------------------------------------------

source(here::here("R", "00_packages.R"))
message("[06_validate_export.R] Validating and exporting GRAVE-D master dataset...")

# -------------------------------------------------------------------------
# 1. LOAD DATASET
# -------------------------------------------------------------------------

grave_d <- readRDS(here("output", "GRAVE_D_Master.rds"))
message("  Loaded: GRAVE_D_Master (", nrow(grave_d), " rows)")

# -------------------------------------------------------------------------
# 2. VALIDATION CHECKS
# -------------------------------------------------------------------------

# Check for duplicates in primary key
duplicates <- grave_d |>
  group_by(COWcode_a, COWcode_b, year) |>
  filter(n() > 1)

if (nrow(duplicates) > 0) {
  stop("ERROR: Duplicate dyad-years found in GRAVE_D_Master!")
} else {
  message("  [Pass] Unique primary keys (COWcode_a, COWcode_b, year).")
}

# Check year range
if (min(grave_d$year, na.rm = TRUE) < 1946 || max(grave_d$year, na.rm = TRUE) > 2020) {
  warning("WARNING: Year range outside 1946-2020 found.")
} else {
  message("  [Pass] Year range 1946-2020.")
}

# Check mid_initiated consistency (0, 1, or NA)
invalid_mid <- grave_d |>
  filter(!is.na(mid_initiated) & !mid_initiated %in% c(0, 1))

if (nrow(invalid_mid) > 0) {
  warning("WARNING: mid_initiated contains values other than 0, 1, or NA.")
} else {
  message("  [Pass] mid_initiated is binary (0/1/NA).")
}

# -------------------------------------------------------------------------
# 3. EXPORT TO READY_DATA
# -------------------------------------------------------------------------

dir.create(here("ready_data"), showWarnings = FALSE, recursive = TRUE)

# Export standard master dataset
data.table::fwrite(grave_d, here("ready_data", "GRAVE_D_Master.csv"), na = "NA")
message("  Exported: ready_data/GRAVE_D_Master.csv")

# Export master dataset with leaders (currently identical copy as per plan)
data.table::fwrite(grave_d, here("ready_data", "GRAVE_D_Master_with_Leaders.csv"), na = "NA")
message("  Exported: ready_data/GRAVE_D_Master_with_Leaders.csv")

message("[06_validate_export.R] Done.")
