# =============================================================================
# utils_imputation.R
# Utility functions for imputation logic.
# =============================================================================

# Function: within-country interpolation + carry forward/backward
impute_country_panel <- function(df, vars, cow_col) {
        # df must have columns: cow_col, year, and all vars
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
                                                # Linear interpolation + extrapolation at edges (rule = 2)
                                                approx(yrs[observed], vals[observed], xout = yrs, rule = 2)$y
                                        } else if (n_obs == 1) {
                                                # Single observation: carry to all years for this country
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
