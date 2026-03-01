# =============================================================================
# 00_packages.R
# Package loading for grave_d_data2026 data pipeline
#
# Run this file first (or source it from other scripts) to ensure all
# required packages are installed and loaded.
#
# Notes:
#   - V-Dem data is accessed via the vdemdata R package, NOT from flat
#     files in source_data/vdem/. If the vdemdata package is not installed,
#     04_build_controls.R will skip V-Dem variables and issue a warning.
#   - All raw external files used by the pipeline live under source_data/,
#     not data/ or ready_data/.
# =============================================================================

# --- Core data manipulation ---
library(here)         # Portable file paths
library(tidyverse)    # dplyr, tidyr, readr, ggplot2, purrr, stringr, forcats
library(data.table)   # Fast large-file reading (fread)

# --- Data import formats ---
library(haven)        # Read Stata (.dta), SPSS (.sav) files
library(readxl)       # Read Excel files

# --- COW / Country code matching ---
library(countrycode)  # Convert between ISO, COW, and other country codes

# --- Date / time ---
library(lubridate)    # Date manipulation

# --- String utilities ---
library(stringr)      # String manipulation (part of tidyverse, explicit load)

# --- Progress reporting ---
library(cli)          # Progress bars and CLI messaging

# --- V-Dem (used in 04_build_controls.R) ---
# vdemdata is loaded conditionally in 04_build_controls.R via
# requireNamespace("vdemdata", quietly = TRUE).
# Install with: remotes::install_github("vdemdata/vdemdata")

message("[00_packages.R] All packages loaded.")

# Install any missing packages:
# pak::pkg_install(c(
#   "here", "tidyverse", "data.table", "haven", "readxl",
#   "countrycode", "lubridate", "stringr", "cli"
# ))
# remotes::install_github("vdemdata/vdemdata")
