library(testthat)
library(dplyr)
library(rlang)

# Load the imputation logic
source(here::here("R", "utils_imputation.R"))

test_that("impute_country_panel correctly interpolates and extrapolates data", {
        # Create a mock dataframe covering multiple test scenarios
        mock_df <- tibble(
                cow = c(
                        # Country 2: Two observations (tests interpolation and extrapolation)
                        2, 2, 2, 2, 2,
                        # Country 20: Single observation (tests carry to all years)
                        20, 20, 20,
                        # Country 40: All NA (tests all NA handling)
                        40, 40, 40,
                        # Country 60: Two observations with large gap
                        60, 60, 60
                ),
                year = c(
                        2000, 2001, 2002, 2003, 2004, # Country 2
                        2000, 2001, 2002,             # Country 20
                        2000, 2001, 2002,             # Country 40
                        2000, 2001, 2002              # Country 60
                ),
                var1 = c(
                        NA, 10, NA, 30, NA,   # Country 2: extrapolate back to 10, interpolate 20, extrapolate forward to 30
                        NA, 5, NA,            # Country 20: carry 5 everywhere
                        NA, NA, NA,           # Country 40: remain all NA
                        100, NA, 300          # Country 60: interpolate 200
                ),
                var2 = c(
                        1, 2, 3, 4, 5,        # Country 2: no missing
                        NA, NA, NA,           # Country 20: remain all NA
                        9, NA, NA,            # Country 40: single observation, carry 9 everywhere
                        NA, NA, NA            # Country 60: remain all NA
                )
        )

        # We need to scramble it a bit to test that it sorts correctly inside the function
        mock_df <- mock_df |> sample_frac(1L)

        # Apply imputation
        result_df <- impute_country_panel(mock_df, vars = c("var1", "var2"), cow_col = "cow")

        # Verify Country 2: var1 should be 10, 10, 20, 30, 30
        c2 <- result_df |> filter(cow == 2) |> arrange(year)
        expect_equal(c2$var1, c(10, 10, 20, 30, 30))
        expect_equal(c2$var2, c(1, 2, 3, 4, 5))

        # Verify Country 20: var1 should be 5 everywhere
        c20 <- result_df |> filter(cow == 20) |> arrange(year)
        expect_equal(c20$var1, c(5, 5, 5))
        expect_equal(c20$var2, as.numeric(c(NA, NA, NA)))

        # Verify Country 40: var1 is all NA, var2 is 9 everywhere
        c40 <- result_df |> filter(cow == 40) |> arrange(year)
        expect_equal(c40$var1, as.numeric(c(NA, NA, NA)))
        expect_equal(c40$var2, c(9, 9, 9))

        # Verify Country 60: var1 interpolates to 200
        c60 <- result_df |> filter(cow == 60) |> arrange(year)
        expect_equal(c60$var1, c(100, 200, 300))
        expect_equal(c60$var2, as.numeric(c(NA, NA, NA)))
})
