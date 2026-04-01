library(testthat)
library(withr)
library(readr)
library(dplyr)
library(fs)

test_that("01_build_fbic_spine filters correctly and creates accurate spine", {

  # Store the original project root safely. test_path("..", "..") gets us to the root.
  # If we're not running via testthat, fallback to getwd() or here::here()
  project_root <- if (isNamespaceLoaded("testthat") && tryCatch(testthat::is_testing(), error = function(e) FALSE)) {
    normalizePath(testthat::test_path("../../"), winslash = "/")
  } else if ("here" %in% loadedNamespaces() || requireNamespace("here", quietly = TRUE)) {
    here::here()
  } else {
    getwd()
  }

  # Create a temporary directory structure matching the expected repo layout
  tmp_dir <- tempfile(pattern = "grave_d_test_")
  dir.create(tmp_dir)

  # Ensure we clean up the tmp_dir AND restore the `here` cache
  withr::defer({
    unlink(tmp_dir, recursive = TRUE)
    if ("here" %in% loadedNamespaces()) {
      unloadNamespace("here")
    }
    # Temporarily set wd back to project_root to let here() re-initialize correctly
    withr::with_dir(project_root, {
      requireNamespace("here", quietly = TRUE)
      here::here() # trigger cache rebuild
    })
  })

  # Create the required subdirectories
  dir.create(file.path(tmp_dir, "R"))
  dir.create(file.path(tmp_dir, "source_data", "fbic"), recursive = TRUE)
  dir.create(file.path(tmp_dir, "data"))

  # Write mock data
  mock_fbic_data <- data.frame(
    iso3a = c("USA", "USA", "USA", "USA", "XXX"), # XXX is invalid ISO code
    iso3b = c("CAN", "USA", "GBR", "MEX", "CAN"),
    year = c(2000, 2005, 1940, 2025, 2010), # 1940 and 2025 are out of bounds
    bandwidth = c(0.8, 0.9, 0.5, 0.7, 0.2),
    economicbandwidth = c(0.4, 0.4, 0.2, 0.3, 0.1),
    politicalbandwidth = c(0.2, 0.3, 0.1, 0.2, 0.1),
    securitybandwidth = c(0.2, 0.2, 0.2, 0.2, 0.0)
  )

  mock_csv_path <- file.path(tmp_dir, "source_data", "fbic", "FBIC_dyadic.csv")
  write.csv(mock_fbic_data, mock_csv_path, row.names = FALSE)

  # We need to copy 00_packages.R so it can be sourced
  file.copy(from = file.path(project_root, "R", "00_packages.R"),
            to = file.path(tmp_dir, "R", "00_packages.R"))

  # We need to copy 01_build_fbic_spine.R to source it locally within the temp dir
  file.copy(from = file.path(project_root, "R", "01_build_fbic_spine.R"),
            to = file.path(tmp_dir, "R", "01_build_fbic_spine.R"))

  # Create an empty .here file to trick `here` package into seeing tmp_dir as project root
  file.create(file.path(tmp_dir, ".here"))

  withr::with_dir(tmp_dir, {
    # Unload here if it's loaded to reset its cache, then load it in tmp_dir
    if ("here" %in% loadedNamespaces()) {
      unloadNamespace("here")
    }
    library(here)

    # Execute the script
    source(file.path("R", "01_build_fbic_spine.R"), local = TRUE)

    # Read the output
    spine <- readRDS(file.path("data", "spine_fbic.rds"))
  })

  # Verify expectations

  # 1. Normal dyad (USA-CAN, 2000) should be present
  expect_true(any(spine$iso3a == "USA" & spine$iso3b == "CAN" & spine$year == 2000))

  # 2. Self-directed dyad (USA-USA, 2005) should be filtered out
  expect_false(any(spine$iso3a == "USA" & spine$iso3b == "USA"))

  # 3. Out-of-bounds years (1940, 2025) should be filtered out
  expect_false(any(spine$year < 1946 | spine$year > 2020))

  # 4. Invalid ISO code (XXX) should map to NA COWcode and be filtered out
  expect_false(any(spine$iso3a == "XXX"))

  # 5. Check if derived variables exist
  expect_true(all(c("COWcode_a", "COWcode_b", "dyad", "unregiona", "unregionb") %in% names(spine)))

  # 6. Check if dyad format is correct (e.g. 002_020)
  expect_true(all(grepl("^\\d{3}_\\d{3}$", spine$dyad)))

})
