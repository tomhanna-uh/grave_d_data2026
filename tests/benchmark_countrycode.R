library(countrycode)
library(dplyr)
library(microbenchmark)

# --- 1. Create Mock Data ---
n <- 100000 # 100,000 rows, typical for a dyadic dataset
cow_codes <- c(2, 20, 200, 220, 300, 365, 400, 420, 500, 600, 700, 800, 900) # Sample codes

set.seed(42)
grave_d <- data.frame(
  COWcode_a = sample(cow_codes, n, replace = TRUE),
  COWcode_b = sample(cow_codes, n, replace = TRUE)
)

message("Mock data size: ", n, " rows")

# --- 2. Define Original Approach ---
original_approach <- function(df) {
  df |>
    mutate(
      unregiona = countrycode(COWcode_a, "cown", "un.region.name", warn = FALSE),
      unregionb = countrycode(COWcode_b, "cown", "un.region.name", warn = FALSE)
    )
}

# --- 3. Define Optimized Approach ---
optimized_approach <- function(df) {
  # Get unique codes
  all_codes <- unique(c(df$COWcode_a, df$COWcode_b))
  all_codes <- all_codes[!is.na(all_codes)]

  if (length(all_codes) > 0) {
    # Compute regions for unique codes
    regions <- countrycode(all_codes, "cown", "un.region.name", warn = FALSE)
    names(regions) <- as.character(all_codes)

    df |>
      mutate(
        unregiona = regions[as.character(COWcode_a)],
        unregionb = regions[as.character(COWcode_b)]
      )
  } else {
    df |> mutate(unregiona = NA_character_, unregionb = NA_character_)
  }
}

# --- 4. Benchmark ---
# Only run if microbenchmark is available (it might not be in the environment, but code is correct)
if (requireNamespace("microbenchmark", quietly = TRUE)) {
  res <- microbenchmark(
    Original = original_approach(grave_d),
    Optimized = optimized_approach(grave_d),
    times = 10
  )
  print(res)
} else {
  # Simple timing fallback
  start_time <- Sys.time()
  res_orig <- original_approach(grave_d)
  end_time <- Sys.time()
  message("Original time: ", end_time - start_time)

  start_time <- Sys.time()
  res_opt <- optimized_approach(grave_d)
  end_time <- Sys.time()
  message("Optimized time: ", end_time - start_time)
}

# --- 5. Verify Results ---
res_orig <- original_approach(grave_d)
res_opt <- optimized_approach(grave_d)

# Check if unregion columns match (handling NAs)
match_a <- identical(res_orig$unregiona, res_opt$unregiona)
match_b <- identical(res_orig$unregionb, res_opt$unregionb)

if (match_a && match_b) {
  message("SUCCESS: Optimized results match original results.")
} else {
  stop("FAILURE: Optimized results do NOT match original results.")
}
