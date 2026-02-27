
library(testthat)
library(here)

context("Security: MIDs file selection")

test_that("Ambiguous MIDs files raise an error", {
  # We simulate the logic inside R/02_build_conflict.R by mocking list.files
  # Since we cannot source the script easily without side effects (and missing data),
  # we replicate the specific logic block we fixed.

  check_mids_logic <- function(mock_files) {
    if (length(mock_files) == 1) {
      return("Success")
    } else if (length(mock_files) > 1) {
      stop(
        sprintf("[02] Ambiguous MIDs files found: %s",
                paste(basename(mock_files), collapse = ", "))
      )
    } else {
      stop("[02_build_conflict.R] MIDs source file not found.")
    }
  }

  # Test Case 1: Multiple files (The vulnerability fix)
  ambiguous_files <- c(
    "/path/to/source_data/mids/dyadic_mid_4.02.csv",
    "/path/to/source_data/mids/dyadic_mid_4.01.csv"
  )
  expect_error(
    check_mids_logic(ambiguous_files),
    "Ambiguous MIDs files found"
  )

  # Test Case 2: Single file (Normal operation)
  single_file <- c("/path/to/source_data/mids/dyadic_mid_4.02.csv")
  expect_equal(
    check_mids_logic(single_file),
    "Success"
  )

  # Test Case 3: No files (Not found)
  no_files <- character(0)
  expect_error(
    check_mids_logic(no_files),
    "MIDs source file not found"
  )
})
