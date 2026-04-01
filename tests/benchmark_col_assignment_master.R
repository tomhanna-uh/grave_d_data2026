# Benchmark script to establish performance methodology for vectorized column assignments
# in R/05_build_master.R when the R runtime is unavailable.

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
  has_vy <- vy_names %in% df_names
  has_base <- vars %in% df_names

  # 1. Assign from .x where .x exists
  if (any(has_vx)) {
    cols_to_assign <- vars[has_vx]
    src_cols <- vx_names[has_vx]
    df[cols_to_assign] <- df[src_cols]
  }

  # 2. Fallback to .y where:
  #    - base v did not exist initially
  #    - vx did not exist
  #    - vy does exist
  needs_vy <- !has_base & !has_vx & has_vy
  if (any(needs_vy)) {
    cols_to_assign_y <- vars[needs_vy]
    src_cols_y <- vy_names[needs_vy]
    df[cols_to_assign_y] <- df[src_cols_y]
  }

  return(df)
}

cat("Benchmarking loop approach...\n")
time_loop <- system.time({
  df_res1 <- method_loop(df_base, core_spine_vars)
})
print(time_loop)

cat("Benchmarking vectorized approach...\n")
time_vec <- system.time({
  df_res2 <- method_vectorized(df_base, core_spine_vars)
})
print(time_vec)

stopifnot(identical(df_res1, df_res2))

speedup <- time_loop["elapsed"] / time_vec["elapsed"]
cat(sprintf("\nSpeedup: %.2fx\n", speedup))
