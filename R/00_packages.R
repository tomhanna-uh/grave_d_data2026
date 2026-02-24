# =============================================================================
# 00_packages.R
# Package loading for grave_d_data2026 data pipeline
#
# Run this file first (or source it from other scripts) to ensure all
# required packages are installed and loaded.
# =============================================================================

# --- Core data manipulation ---
library(here)        # Portable file paths
library(tidyverse)   # dplyr, tidyr, readr, ggplot2, purrr, stringr, forcats
library(data.table)  # Fast large-file reading (fread)

# --- Data import formats ---
library(haven)       # Read Stata (.dta), SPSS (.sav) files
library(readxl)      # Read Excel files

# --- COW / Country code matching ---
library(countrycode) # Convert between ISO, COW, and other country codes

# --- Date / time ---
library(lubridate)   # Date manipulation

# --- String utilities ---
library(stringr)     # String manipulation (part of tidyverse, explicit load)

# --- Progress reporting ---
library(cli)         # Progress bars and CLI messaging

# --- Testing ---
library(testthat)    # Unit testing

message("[00_packages.R] All packages loaded.")

# Install any missing packages:
# pak::pkg_install(c(
#   "here", "tidyverse", "data.table", "haven", "readxl",
#   "countrycode", "lubridate", "stringr", "cli", "testthat"
# ))
