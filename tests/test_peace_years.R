# =============================================================================
# tests/test_peace_years.R
# Test suite for peace years calculation logic
# =============================================================================

# Load required packages (simulating environment)
# In a real R session, testthat would manage this context.
library(testthat)
library(dplyr)

# Source the function to be tested
# Using relative path assuming execution from project root or adjusted in test runner
source(here::here("R", "utils_conflict.R"))

test_that("Scenario 1: No Conflict - defaults to 35", {
  # Setup: Single dyad, 5 years, no conflict
  df <- tibble(
    dyad = "A-B",
    year = 2000:2004,
    mid_initiated = 0L
  )

  result <- calculate_peace_years(df)

  # Expect peace_years to be 35 for all rows (default when no prior conflict known)
  expect_equal(result$peace_years, rep(35L, 5))
  expect_equal(result$t, rep(35L, 5))
  expect_equal(result$t2, rep(35L^2, 5))
})

test_that("Scenario 2: Conflict Reset - resets to 0 on conflict year", {
  # Setup: Conflict in 2002
  df <- tibble(
    dyad = "A-B",
    year = 2000:2004,
    mid_initiated = c(0L, 0L, 1L, 0L, 0L)
  )

  result <- calculate_peace_years(df)

  # 2000, 2001: No prior conflict known -> 35
  # 2002: Conflict -> 0 (year - year)
  # 2003: 1 year peace -> 1
  # 2004: 2 years peace -> 2
  expected_peace <- c(35L, 35L, 0L, 1L, 2L)

  expect_equal(result$peace_years, expected_peace)
})

test_that("Scenario 3: Consecutive Conflicts", {
  # Setup: Conflict in 2001 and 2002
  df <- tibble(
    dyad = "A-B",
    year = 2000:2004,
    mid_initiated = c(0L, 1L, 1L, 0L, 0L)
  )

  result <- calculate_peace_years(df)

  # 2000: 35
  # 2001: 0
  # 2002: 0
  # 2003: 1
  # 2004: 2
  expected_peace <- c(35L, 0L, 0L, 1L, 2L)

  expect_equal(result$peace_years, expected_peace)
})

test_that("Scenario 4: Multiple Dyads - isolated calculations", {
  # Setup: Two dyads
  # Dyad 1: Conflict in 2001
  # Dyad 2: No conflict
  df <- tibble(
    dyad = c(rep("A-B", 3), rep("C-D", 3)),
    year = c(2000, 2001, 2002, 2000, 2001, 2002),
    mid_initiated = c(0L, 1L, 0L, 0L, 0L, 0L)
  )

  result <- calculate_peace_years(df)

  # Split results by dyad
  res_ab <- result |> filter(dyad == "A-B")
  res_cd <- result |> filter(dyad == "C-D")

  # A-B: 35, 0, 1
  expect_equal(res_ab$peace_years, c(35L, 0L, 1L))

  # C-D: 35, 35, 35
  expect_equal(res_cd$peace_years, c(35L, 35L, 35L))
})

test_that("Scenario 5: Unordered Input - sorts correctly", {
  # Setup: Unordered years
  df <- tibble(
    dyad = "A-B",
    year = c(2002, 2000, 2001),
    mid_initiated = c(0L, 0L, 1L)
  )

  result <- calculate_peace_years(df)

  # Should be sorted to 2000, 2001, 2002
  # 2000: 35
  # 2001: 0 (conflict)
  # 2002: 1

  expect_equal(result$year, c(2000, 2001, 2002))
  expect_equal(result$peace_years, c(35L, 0L, 1L))
})

test_that("Validation: Missing columns error", {
  df <- tibble(year = 2000, mid_initiated = 0) # Missing dyad
  expect_error(calculate_peace_years(df), "must contain 'dyad', 'year', and 'mid_initiated'")
})
