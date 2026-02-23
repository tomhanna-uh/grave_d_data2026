# =============================================================================
# 04_build_controls.R
# Merge V-Dem, COW CINC, and WDI control variables
# =============================================================================
source(here::here("R", "00_packages.R"))
message("[04_build_controls.R] Starting controls merge...")
spine <- readRDS(here("output", "spine_ideology.rds"))
vdem_path <- here("source_data", "vdem", "V-Dem-CY-Full+Others-v13.rds")
if (file.exists(vdem_path)) {
  vdem_data <- readRDS(vdem_path) |>
    select(COWcode = country_id, year, v2x_libdem, v2exl_legitideol, v2exl_legitperf, v2exl_legitlead, v2x_corr)
} else { vdem_data <- NULL }
cinc_path <- here("source_data", "cow", "NMC_v6.0.csv")
if (file.exists(cinc_path)) {
  cinc_data <- as_tibble(data.table::fread(cinc_path)) |> select(COWcode = ccode, year, cinc)
} else { cinc_data <- NULL }
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
spine_controls <- spine_controls |>
  mutate(targets_democracy = if_else(v2x_libdem_b >= 0.5, 1L, 0L),
         cold_war = if_else(year >= 1947 & year <= 1991, 1L, 0L))
saveRDS(spine_controls, here("output", "spine_controls.rds"))
message("[04_build_controls.R] Done.")
