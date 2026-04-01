library(dplyr)
library(microbenchmark)

# Generate a dummy dataset
set.seed(123)
n_rows <- 1e6
n_cols <- 10

df_base <- as.data.frame(matrix(rnorm(n_rows * n_cols), nrow = n_rows))
# Introduce NAs
df_base[sample(1:(n_rows * n_cols), n_rows * n_cols * 0.1)] <- NA
names(df_base) <- paste0("nonstate_", 1:n_cols)

# Method 1: Loop
method_loop <- function(df) {
  ns_cols <- grep("^nonstate_", names(df), value = TRUE)
  for (col in ns_cols) {
    df[[col]] <- if_else(is.na(df[[col]]), 0L, as.integer(df[[col]]))
  }
  return(df)
}

# Method 2: Vectorized
method_vectorized <- function(df) {
  ns_cols <- grep("^nonstate_", names(df), value = TRUE)
  df <- df |> mutate(across(all_of(ns_cols), ~ if_else(is.na(.), 0L, as.integer(.))))
  return(df)
}

# Run benchmark
mbm <- microbenchmark(
  Loop = method_loop(df_base),
  Vectorized = method_vectorized(df_base),
  times = 10
)

print(mbm)
