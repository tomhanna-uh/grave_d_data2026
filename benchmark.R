library(dplyr)
library(tidyr)

# Create some dummy data
set.seed(123)
n_countries <- 100
n_years <- 50
n_vars <- 10

df <- expand_grid(cowcode = 1:n_countries, year = 1950:(1950 + n_years - 1))
for (i in 1:n_vars) {
  df[[paste0("v", i)]] <- rnorm(nrow(df))
  # Introduce some NAs
  df[[paste0("v", i)]][sample(1:nrow(df), nrow(df) * 0.2)] <- NA
}

vars <- paste0("v", 1:n_vars)
cow_col <- "cowcode"

# Current approach
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

# New approach
impute_country_panel_new <- function(df, vars, cow_col) {
  df <- df |> arrange(!!sym(cow_col), year)

  # Filter variables that exist and are not entirely NA
  vars_to_impute <- vars[vars %in% names(df)]
  vars_to_impute <- vars_to_impute[sapply(df[vars_to_impute], function(x) !all(is.na(x)))]

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

# Check correctness
res1 <- impute_country_panel_current(df, vars, cow_col)
res2 <- impute_country_panel_new(df, vars, cow_col)
stopifnot(all.equal(res1, res2))

# Benchmark
res <- microbenchmark::microbenchmark(
  current = impute_country_panel_current(df, vars, cow_col),
  new = impute_country_panel_new(df, vars, cow_col),
  times = 10
)
print(res)
