# Benchmark for dyad ID creation
# This script compares the performance of the original paste0() method
# versus the optimized sprintf() method for creating dyad identifiers.

if (!requireNamespace("microbenchmark", quietly = TRUE)) {
  install.packages("microbenchmark")
}
if (!requireNamespace("dplyr", quietly = TRUE)) {
  install.packages("dplyr")
}

library(microbenchmark)
library(dplyr)

# Simulate a large dataset similar to what might be in the pipeline
n_rows <- 100000
set.seed(123)
df <- tibble(
  COWcode_a = sample(2:999, n_rows, replace = TRUE),
  COWcode_b = sample(2:999, n_rows, replace = TRUE)
)

cat("Benchmarking dyad creation on", n_rows, "rows...\n")

# Benchmark
mb <- microbenchmark(
  original = {
    df %>%
      mutate(
        dyad = paste0(
          sprintf("%03d", COWcode_a), "_",
          sprintf("%03d", COWcode_b)
        )
      )
  },
  optimized = {
    df %>%
      mutate(
        dyad = sprintf("%03d_%03d", COWcode_a, COWcode_b)
      )
  },
  times = 50
)

print(mb)

# Validate that both methods produce the same result
res_orig <- df %>%
  mutate(
    dyad = paste0(
      sprintf("%03d", COWcode_a), "_",
      sprintf("%03d", COWcode_b)
    )
  )

res_opt <- df %>%
  mutate(
    dyad = sprintf("%03d_%03d", COWcode_a, COWcode_b)
  )

if (identical(res_orig$dyad, res_opt$dyad)) {
  cat("\nValidation Passed: Both methods produce identical dyad IDs.\n")
} else {
  cat("\nValidation FAILED: Methods produce different results.\n")
}
