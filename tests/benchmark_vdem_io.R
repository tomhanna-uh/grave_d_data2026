# tests/benchmark_vdem_io.R
# Benchmark script to compare full V-Dem read vs cached subset read

# Load packages
if (file.exists(here::here("R", "00_packages.R"))) {
  source(here::here("R", "00_packages.R"))
} else {
  library(here)
  library(tidyverse)
  library(data.table)
}

message("[Benchmark] Starting V-Dem I/O benchmark...")

vdem_path <- here("source_data", "vdem", "V-Dem-CY-Full+Others-v13.rds")
subset_path <- here("output", "vdem_controls_subset.rds")

# Ensure output directory exists for benchmark
dir.create(dirname(subset_path), showWarnings = FALSE, recursive = TRUE)

if (!file.exists(vdem_path)) {
  message("Error: V-Dem source file not found at: ", vdem_path)
  message("Skipping benchmark.")
  if (!interactive()) quit(status = 0)
}

# --- Benchmark 1: Full Read ---
message("\n--- Benchmark 1: Reading Full RDS ---")
start_time_full <- Sys.time()
vdem_full <- readRDS(vdem_path)
end_time_full <- Sys.time()
full_read_duration <- as.numeric(difftime(end_time_full, start_time_full, units = "secs"))

message(sprintf("Time: %.4f seconds", full_read_duration))
message("Rows: ", nrow(vdem_full), " Cols: ", ncol(vdem_full))

# Prepare for subset benchmark
# We simulate the process of selecting columns
cols_to_select <- c("country_id", "year", "v2x_libdem", "v2exl_legitideol", "v2exl_legitperf", "v2exl_legitlead", "v2x_corr")

# Create subset file if it doesn't exist or we want to refresh it for the test
message("\n[Setup] Creating/refreshing subset file...")
vdem_subset_create <- vdem_full |>
  select(any_of(cols_to_select)) |>
  rename(COWcode = country_id)

saveRDS(vdem_subset_create, subset_path)
rm(vdem_full, vdem_subset_create)
gc()

# --- Benchmark 2: Subset Read ---
message("\n--- Benchmark 2: Reading Cached Subset RDS ---")
start_time_subset <- Sys.time()
vdem_subset <- readRDS(subset_path)
end_time_subset <- Sys.time()
subset_read_duration <- as.numeric(difftime(end_time_subset, start_time_subset, units = "secs"))

message(sprintf("Time: %.4f seconds", subset_read_duration))
message("Rows: ", nrow(vdem_subset), " Cols: ", ncol(vdem_subset))

# --- Results ---
speedup <- full_read_duration / subset_read_duration
message("\n========================================")
message(sprintf("Speedup Factor: %.2fx", speedup))
message("========================================")

# Clean up
if (file.exists(subset_path)) {
  message("\n[Cleanup] Removing temporary subset file...")
  unlink(subset_path)
}
