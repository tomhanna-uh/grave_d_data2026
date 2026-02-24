# -------------------------------------------------------------------------
# test_data_integrity.R
# Test suite for GRAVE-D master dataset integrity
# -------------------------------------------------------------------------

source(here::here("R", "00_packages.R"))

# Define path to master dataset
grave_d_path <- here("output", "GRAVE_D_Master.rds")

# Only run tests if the dataset exists
if (file.exists(grave_d_path)) {

  grave_d <- readRDS(grave_d_path)

  test_that("Master dataset is not empty", {
    expect_gt(nrow(grave_d), 0)
  })

  test_that("Primary keys are unique", {
    duplicates <- grave_d |>
      dplyr::group_by(COWcode_a, COWcode_b, year) |>
      dplyr::filter(dplyr::n() > 1)

    expect_equal(nrow(duplicates), 0, info = "Duplicate primary keys found")
  })

  test_that("Primary keys have no missing values", {
    missing_keys <- grave_d |>
      dplyr::filter(is.na(COWcode_a) | is.na(COWcode_b) | is.na(year))

    expect_equal(nrow(missing_keys), 0, info = "Missing values in primary keys")
  })

  test_that("Years are within expected range (1946-2020)", {
    expect_true(all(grave_d$year >= 1946))
    expect_true(all(grave_d$year <= 2020))
  })

  test_that("Binary variables are consistent", {
    if ("mid_initiated" %in% names(grave_d)) {
      invalid_mid <- grave_d |>
        dplyr::filter(!mid_initiated %in% c(0, 1) & !is.na(mid_initiated))

      expect_equal(nrow(invalid_mid), 0, info = "Invalid values in mid_initiated")
    }
  })

} else {
  message("Skipping data integrity tests: output/GRAVE_D_Master.rds not found.")
}
