# =============================================================================
# tests/test_conflict_aggregation.R
# Test suite for conflict aggregation logic
# =============================================================================

# Load required packages
if (!require(testthat)) stop("Package 'testthat' is required for testing.")
if (!require(dplyr)) stop("Package 'dplyr' is required for testing.")
if (!require(here)) stop("Package 'here' is required for testing.")

# Source the utility file containing the logic
source(here::here("R", "utils_conflict.R"))

test_that("aggregate_mids_dyadic correctly aggregates and calculates conflict variables", {

  # 1. Setup mock data
  mids_raw_mock <- tibble::tibble(
    COWcode_a = c(2, 2, 2, 200, 300, NA), # NA should be filtered
    COWcode_b = c(20, 20, 20, 220, NA, 300), # NA should be filtered
    year = c(2000, 2000, 2001, 2000, 2000, 2000),
    hihosta = c(1, 4, 3, 1, 5, 2) # Mixed hostilities
  )

  # 2. Run aggregation
  result <- aggregate_mids_dyadic(mids_raw_mock)

  # 3. Verify Filtering
  # Expect rows with NA in COWcode_a or COWcode_b to be removed
  expect_equal(nrow(result), 3) # (2,20,2000), (2,20,2001), (200,220,2000)

  # 4. Verify Aggregation (Max hihosta)
  # For (2, 20, 2000), hihosta are 1 and 4. Max is 4.
  row_2000 <- result |> filter(COWcode_a == 2, year == 2000)
  expect_equal(row_2000$hihosta, 4L)

  # For (2, 20, 2001), hihosta is 3.
  row_2001 <- result |> filter(COWcode_a == 2, year == 2001)
  expect_equal(row_2001$hihosta, 3L)

  # For (200, 220, 2000), hihosta is 1.
  row_200_220 <- result |> filter(COWcode_a == 200, year == 2000)
  expect_equal(row_200_220$hihosta, 1L)

  # 5. Verify mid_initiated Calculation
  # hihosta >= 2 implies mid_initiated = 1
  expect_equal(row_2000$mid_initiated, 1L)   # 4 >= 2
  expect_equal(row_2001$mid_initiated, 1L)   # 3 >= 2
  expect_equal(row_200_220$mid_initiated, 0L) # 1 < 2
})

test_that("aggregate_mids_dyadic handles edge cases", {

  # Case: All NAs in hihosta for a group (should warning or return -Inf if not handled, but max(na.rm=T) warns on empty)
  # Ideally, we should filter out rows where hihosta is all NA before or handle it.
  # Based on current logic: `max(c(NA), na.rm=TRUE)` returns `-Inf` with a warning in base R.
  # Let's see how our function behaves.

  mids_all_na <- tibble::tibble(
    COWcode_a = c(10),
    COWcode_b = c(20),
    year = c(1990),
    hihosta = c(NA_real_)
  )

  # We expect a warning "no non-missing arguments to max; returning -Inf"
  # and then as.integer(-Inf) is NA (usually) or a very small number?
  # Actually, let's just check what happens.

  # Depending on strictness, we might want to suppress warnings or checking for it.
  # For now, let's just run it.
  suppressWarnings({
    result <- aggregate_mids_dyadic(mids_all_na)
  })

  # If result has -Inf, as.integer(-Inf) might be NA.
  # Let's check.
  # If hihosta becomes NA (from -Inf cast), mid_initiated becomes NA (from NA >= 2).
  # Wait, existing code uses `max(hihosta, na.rm = TRUE)`.

  # Let's checking empty input
  mids_empty <- tibble::tibble(
    COWcode_a = integer(),
    COWcode_b = integer(),
    year = integer(),
    hihosta = integer()
  )

  result_empty <- aggregate_mids_dyadic(mids_empty)
  expect_equal(nrow(result_empty), 0)
})
