# This script is a conceptual benchmark for `impute_country_panel`
# to establish a performance baseline, as the R runtime is unavailable.

library(dplyr)
library(tidyr)
library(purrr)

# Generate dummy panel data
set.seed(123)
n_countries <- 100
n_years <- 50
n_vars <- 10

df <- expand_grid(cowcode = 1:n_countries, year = 1950:(1950 + n_years - 1))
for (i in 1:n_vars) {
  df[[paste0("v", i)]] <- rnorm(nrow(df))
  # Introduce some missingness
  df[[paste0("v", i)]][sample(1:nrow(df), nrow(df) * 0.2)] <- NA
}

vars <- paste0("v", 1:n_vars)
cow_col <- "cowcode"

# Current approach: A for loop that groups and mutates repeatedly
impute_country_panel_current <- function(df, vars, cow_col) {
  df <- df |> arrange(!!sym(cow_col), year)

  for (v in vars) {
    if (!v %in% names(df)) next
    if (all(is.na(df[[v]]))) next

    df <- df |>
      group_by(!!sym(cow_col)) |>
      mutate(
        !!v := {
          vals <- .data[[v]]
          yrs  <- year
          observed <- !is.na(vals)
          n_obs <- sum(observed)
          if (n_obs >= 2) {
            approx(yrs[observed], vals[observed], xout = yrs, rule = 2)$y
          } else if (n_obs == 1) {
            replace(vals, TRUE, vals[observed][1])
          } else {
            vals
          }
        }
      ) |>
      ungroup()
  }
  df
}

# New approach: Grouping once and mutating across all valid columns simultaneously
impute_country_panel_new <- function(df, vars, cow_col) {
  df <- df |> arrange(!!sym(cow_col), year)

  # Filter to variables that actually exist in the dataframe
  valid_vars <- intersect(vars, names(df))
  if (length(valid_vars) == 0) return(df)

  # Filter to variables that are not entirely NA
  vars_to_impute <- valid_vars[purrr::map_lgl(df[valid_vars], ~ !all(is.na(.x)))]

  if (length(vars_to_impute) == 0) return(df)

  df <- df |>
    group_by(!!sym(cow_col)) |>
    mutate(
      across(
        all_of(vars_to_impute),
        ~ {
          vals <- .x
          yrs  <- year
          observed <- !is.na(vals)
          n_obs <- sum(observed)
          if (n_obs >= 2) {
            approx(yrs[observed], vals[observed], xout = yrs, rule = 2)$y
          } else if (n_obs == 1) {
            replace(vals, TRUE, vals[observed][1])
          } else {
            vals
          }
        }
      )
    ) |>
    ungroup()

  df
}

# In a real environment, we would run:
# stopifnot(all.equal(impute_country_panel_current(df, vars, cow_col),
#                     impute_country_panel_new(df, vars, cow_col)))
# microbenchmark::microbenchmark(
#   current = impute_country_panel_current(df, vars, cow_col),
#   new = impute_country_panel_new(df, vars, cow_col),
#   times = 10
# )
