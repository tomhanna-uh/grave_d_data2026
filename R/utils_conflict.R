# =============================================================================
# utils_conflict.R
# Helper functions for conflict variable construction
# =============================================================================

#' Calculate Peace Years and Cubic Polynomials
#'
#' This function calculates the number of peace years since the last conflict
#' for each dyad-year, as well as cubic polynomial terms (t, t2, t3) for
#' time-series modeling.
#'
#' Logic:
#' - Group by `dyad`.
#' - `conflict_year`: If `mid_initiated == 1`, set to `year`, else `NA`.
#' - `last_conflict`: Cumulative maximum of `conflict_year` (propagates the last conflict year forward).
#' - `peace_years`: If `last_conflict` is 0 (no prior conflict), default to 35.
#'                  Else, `year - last_conflict`.
#'
#' @param data A dataframe containing columns: `dyad`, `year`, `mid_initiated`.
#' @return A dataframe with added columns: `peace_years`, `t`, `t2`, `t3`.
#' @export
calculate_peace_years <- function(data) {
  if (!all(c("dyad", "year", "mid_initiated") %in% names(data))) {
    stop("Input data must contain 'dyad', 'year', and 'mid_initiated' columns.")
  }

  data |>
    arrange(dyad, year) |>
    group_by(dyad) |>
    mutate(
      conflict_year  = if_else(mid_initiated == 1L, year, NA_integer_),
      last_conflict  = cummax(if_else(is.na(conflict_year), 0L, conflict_year)),
      peace_years    = if_else(last_conflict == 0L, 35L, year - last_conflict),
      t  = peace_years,
      t2 = t^2,
      t3 = t^3
    ) |>
    ungroup() |>
    select(-conflict_year, -last_conflict)
}
