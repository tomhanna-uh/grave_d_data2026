# =============================================================================
# 04_build_controls.R
# Merge V-Dem, COW CINC, and Colgan petro-state control variables
# =============================================================================
source(here::here("R", "00_packages.R"))
message("[04_build_controls.R] Starting controls merge...")

spine <- readRDS(here("output", "spine_ideology.rds"))

# -----------------------------------------------------------------------------
# 1. V-Dem
# -----------------------------------------------------------------------------
vdem_path <- here("source_data", "vdem", "V-Dem-CY-Full+Others-v13.rds")
if (file.exists(vdem_path)) {
  vdem_data <- readRDS(vdem_path) |>
    select(COWcode = country_id, year, v2x_libdem, v2exl_legitideol, v2exl_legitperf, v2exl_legitlead, v2x_corr)
} else { vdem_data <- NULL }

# -----------------------------------------------------------------------------
# 2. COW CINC (National Military Capabilities)
# -----------------------------------------------------------------------------
cinc_path <- here("source_data", "cow", "NMC_v6.0.csv")
if (file.exists(cinc_path)) {
  cinc_data <- as_tibble(data.table::fread(cinc_path)) |> select(COWcode = ccode, year, cinc)
} else { cinc_data <- NULL }

# -----------------------------------------------------------------------------
# 3. Colgan petro-state data
# Source: Colgan (2010/2013) oil wealth dataset
# File:   source_data/colgan/colgan.dta  (Stata format)
# Key variables: COWcode (or ccode), year, petro_state (or oil_income_pc, etc.)
# is_petro_state is coded 1 if oil/gas wealth exceeds threshold
# -----------------------------------------------------------------------------
colgan_path <- here("source_data", "colgan", "colgan.dta")
if (file.exists(colgan_path)) {
  colgan_raw <- haven::read_dta(colgan_path)
  # Standardize column names to lowercase
  colgan_raw <- colgan_raw |> rename_with(tolower)
  # Standardize COW code column
  if ("cowcode" %in% names(colgan_raw)) {
    colgan_raw <- colgan_raw |> rename(COWcode = cowcode)
  } else if ("ccode" %in% names(colgan_raw)) {
    colgan_raw <- colgan_raw |> rename(COWcode = ccode)
  }
  # Build is_petro_state: use existing dummy if present, else derive from
  # oil income per capita or total oil income exceeding a threshold
  if ("petro_state" %in% names(colgan_raw)) {
    colgan_data <- colgan_raw |>
      select(COWcode, year, is_petro_state = petro_state)
  } else if ("petrostate" %in% names(colgan_raw)) {
    colgan_data <- colgan_raw |>
      select(COWcode, year, is_petro_state = petrostate)
  } else {
    # Derive from oil income per capita if available
    oil_col <- grep("^oil", names(colgan_raw), value = TRUE)[1]
    if (!is.na(oil_col)) {
      threshold <- quantile(colgan_raw[[oil_col]], 0.75, na.rm = TRUE)
      colgan_data <- colgan_raw |>
        mutate(is_petro_state = as.integer(.data[[oil_col]] > threshold)) |>
        select(COWcode, year, is_petro_state)
      message(sprintf("[04] is_petro_state derived from '%s' (threshold = %.2f)", oil_col, threshold))
    } else {
      warning("[04] Could not identify petro-state column in colgan.dta; is_petro_state will be NA")
      colgan_data <- colgan_raw |> select(COWcode, year) |> mutate(is_petro_state = NA_integer_)
    }
  }
  colgan_data <- colgan_data |> distinct(COWcode, year, .keep_all = TRUE)
  message(sprintf("[04] Colgan loaded: %d country-year rows", nrow(colgan_data)))
} else {
  colgan_data <- NULL
  message("[04] colgan.dta not found at source_data/colgan/colgan.dta — is_petro_state will be absent")
}

# -----------------------------------------------------------------------------
# 4. Merge all controls onto spine
# -----------------------------------------------------------------------------
spine_controls <- spine

if (!is.null(vdem_data)) {
  spine_controls <- spine_controls |>
    left_join(vdem_data |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)), by = c("COWcode_a" = "COWcode", "year")) |>
    left_join(vdem_data |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)), by = c("COWcode_b" = "COWcode", "year"))
}

if (!is.null(cinc_data)) {
  spine_controls <- spine_controls |>
    left_join(cinc_data |> rename(sidea_national_military_capabilities = cinc), by = c("COWcode_a" = "COWcode", "year")) |>
    left_join(cinc_data |> rename(sideb_national_military_capabilities = cinc), by = c("COWcode_b" = "COWcode", "year"))
}

if (!is.null(colgan_data)) {
  spine_controls <- spine_controls |>
    left_join(colgan_data |> rename(is_petro_state_a = is_petro_state), by = c("COWcode_a" = "COWcode", "year")) |>
    left_join(colgan_data |> rename(is_petro_state_b = is_petro_state), by = c("COWcode_b" = "COWcode", "year"))
}

# -----------------------------------------------------------------------------
# 5. Derived variables
# -----------------------------------------------------------------------------
spine_controls <- spine_controls |>
  mutate(
    targets_democracy = if_else(v2x_libdem_b >= 0.5, 1L, 0L),
    cold_war          = if_else(year >= 1947 & year <= 1991, 1L, 0L)
  )

saveRDS(spine_controls, here("output", "spine_controls.rds"))
message("[04_build_controls.R] Done.")
