# =============================================================================
# R/utils_conflict.R
# Utility functions for conflict data processing
# =============================================================================

#' Aggregate MIDs dyadic data to dyad-year level
#'
#' Takes raw MIDs dyadic data, filters invalid rows, and aggregates to
#' one row per dyad-year by taking the maximum hostility level (hihosta).
#'
#' @param mids_raw A dataframe containing at least COWcode_a, COWcode_b, year, and hihosta columns.
#' @return A dataframe with aggregated conflict data (hihosta, mid_initiated) per dyad-year.
aggregate_mids_dyadic <- function(mids_raw) {
  mids_dyadic <- mids_raw |>
    filter(!is.na(COWcode_a), !is.na(COWcode_b)) |>
    select(COWcode_a, COWcode_b, year, hihosta) |>
    group_by(COWcode_a, COWcode_b, year) |>
    summarise(
      hihosta = max(hihosta, na.rm = TRUE),
      .groups = "drop"
    ) |>
    mutate(
      hihosta = as.integer(hihosta),
      mid_initiated = as.integer(hihosta >= 2L)
    )

  return(mids_dyadic)
}
