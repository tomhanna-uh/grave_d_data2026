# R specific benchmark script to establish the optimization validity
n_rows <- 1000000
core_spine_vars <- paste0("var", 1:17)

df_base <- data.frame(
  matrix(runif(n_rows * 34), nrow = n_rows, ncol = 34)
)
names(df_base) <- c(paste0(core_spine_vars, ".x"), paste0(core_spine_vars, ".y"))

method_loop <- function(df, vars) {
  for (v in vars) {
    vx <- paste0(v, ".x")
    vy <- paste0(v, ".y")

    if (vx %in% names(df)) {
      df[[v]] <- df[[vx]]
    } else if (!(v %in% names(df)) && vy %in% names(df)) {
      df[[v]] <- df[[vy]]
    }
  }
  return(df)
}

method_vectorized <- function(df, vars) {
  df_names <- names(df)

  vx_names <- paste0(vars, ".x")
  vy_names <- paste0(vars, ".y")

  has_vx <- vx_names %in% df_names

  if (any(has_vx)) {
    cols_to_assign <- vars[has_vx]
    src_cols <- vx_names[has_vx]
    df[cols_to_assign] <- df[src_cols]
  }

  # Check if we should fallback to .y for any of them.
  # We should do this only if .x wasn't found (or if we shouldn't overwrite base 'v' if it existed?
  # The original logic:
  # if (vx %in% names) {
  #   df[[v]] <- df[[vx]]
  # } else if (!(v %in% names(df)) && vy %in% names(df)) {
  #   df[[v]] <- df[[vy]]
  # }
  # The logic says: fallback to vy if v does NOT exist and vx does NOT exist.

  # Let's say we have df_names at the START.
  # v didn't exist originally if v not in df_names
  has_base_orig <- vars %in% df_names
  has_vy <- vy_names %in% df_names

  needs_vy <- !has_vx & !has_base_orig & has_vy

  if (any(needs_vy)) {
    cols_to_assign_y <- vars[needs_vy]
    src_cols_y <- vy_names[needs_vy]
    df[cols_to_assign_y] <- df[src_cols_y]
  }

  return(df)
}

time_loop <- system.time(method_loop(df_base, core_spine_vars))
time_vec <- system.time(method_vectorized(df_base, core_spine_vars))

cat(sprintf("Loop time: %.4f seconds\n", time_loop["elapsed"]))
cat(sprintf("Vec time:  %.4f seconds\n", time_vec["elapsed"]))
cat(sprintf("Speedup:   %.2fx\n", time_loop["elapsed"] / time_vec["elapsed"]))
