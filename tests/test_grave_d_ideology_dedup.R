# tests/test_grave_d_ideology_dedup.R

suppressPackageStartupMessages(library(dplyr))

# Mock data with identical duplicates (should pass)
df_identical <- data.frame(
  COWcode = c(2, 2, 3),
  year = c(2000, 2000, 2001),
  var1 = c("A", "A", "B"),
  var2 = c(1, 1, 2)
)

# Mock data with conflicting duplicates (should fail)
df_conflict <- data.frame(
  COWcode = c(2, 2, 3),
  year = c(2000, 2000, 2001),
  var1 = c("A", "B", "B"), # Conflict here
  var2 = c(1, 1, 2)
)

check_duplicates <- function(df, key_cols = c("COWcode", "year")) {
  duplicates <- df |>
    dplyr::group_by(dplyr::across(dplyr::all_of(key_cols))) |>
    dplyr::filter(dplyr::n() > 1)

  if (nrow(duplicates) > 0) {
    # Check if they are truly different
    non_identical <- duplicates |>
      dplyr::distinct() |>
      dplyr::group_by(dplyr::across(dplyr::all_of(key_cols))) |>
      dplyr::filter(dplyr::n() > 1)

    if (nrow(non_identical) > 0) {
      stop("Found conflicting duplicates!")
    }
  }

  return(dplyr::distinct(df, dplyr::across(dplyr::all_of(key_cols)), .keep_all = TRUE))
}

# Test 1: Identical duplicates
tryCatch({
  res <- check_duplicates(df_identical)
  if (nrow(res) != 2) stop("Test 1 Failed: Should have 2 rows")
  message("Test 1 Passed")
}, error = function(e) {
  stop("Test 1 Failed with error: ", e$message)
})

# Test 2: Conflicting duplicates
tryCatch({
  check_duplicates(df_conflict)
  stop("Test 2 Failed: Should have thrown an error")
}, error = function(e) {
  if (grepl("Found conflicting duplicates", e$message)) {
    message("Test 2 Passed")
  } else {
    stop("Test 2 Failed with unexpected error: ", e$message)
  }
})
