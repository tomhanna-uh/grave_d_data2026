
library(data.table)
library(dplyr)

# Mock data generation parameters
n_countries <- 200
n_years <- 75 # 1946-2020

# Create mock spine
countries <- 1:n_countries
years <- 1946:(1946 + n_years - 1)

spine <- expand.grid(COWcode_a = countries, COWcode_b = countries, year = years)
spine <- spine[spine$COWcode_a != spine$COWcode_b, ] # Remove self-loops
spine$some_data <- runif(nrow(spine))

# Create mock mids_dyadic
# Assume some conflicts
n_conflicts <- 5000
mids_dyadic <- data.frame(
  COWcode_a = sample(countries, n_conflicts, replace = TRUE),
  COWcode_b = sample(countries, n_conflicts, replace = TRUE),
  year = sample(years, n_conflicts, replace = TRUE),
  hihosta = sample(1:5, n_conflicts, replace = TRUE)
)
mids_dyadic <- mids_dyadic[mids_dyadic$COWcode_a != mids_dyadic$COWcode_b, ]
mids_dyadic$mid_initiated <- as.integer(mids_dyadic$hihosta >= 2)

# Remove duplicates in mids_dyadic for join key uniqueness (simplification)
mids_dyadic <- mids_dyadic[!duplicated(mids_dyadic[, c("COWcode_a", "COWcode_b", "year")]), ]

cat("Spine rows:", nrow(spine), "\n")
cat("Mids rows:", nrow(mids_dyadic), "\n")

# Current implementation using dplyr
run_dplyr <- function() {
  # Copy to avoid side effects in benchmark
  spine_copy <- spine
  mids_copy <- mids_dyadic

  spine_conflict <- spine_copy |>
    left_join(
      mids_copy,
      by = c("COWcode_a", "COWcode_b", "year")
    ) |>
    mutate(
      hihosta = if_else(is.na(hihosta), 0L, as.integer(hihosta)),
      mid_initiated = if_else(is.na(mid_initiated), 0L, mid_initiated)
    )
  return(spine_conflict)
}

# Optimized implementation using data.table
run_datatable <- function() {
  # Convert to data.table inside the function to include conversion cost if applicable
  # or assume we convert once. The prompt implies converting to data.table.

  dt_spine <- as.data.table(spine)
  dt_mids <- as.data.table(mids_dyadic)

  # Set keys for faster join (this is usually done automatically by merge but explicit is good)
  setkey(dt_spine, COWcode_a, COWcode_b, year)
  setkey(dt_mids, COWcode_a, COWcode_b, year)

  # data.table merge
  dt_res <- merge(dt_spine, dt_mids, all.x = TRUE, by = c("COWcode_a", "COWcode_b", "year"))

  # Fill NA values
  dt_res[is.na(hihosta), hihosta := 0L]
  dt_res[is.na(mid_initiated), mid_initiated := 0L]

  return(dt_res)
}

# Run benchmark
if (requireNamespace("bench", quietly = TRUE)) {
  res <- bench::mark(
    dplyr = run_dplyr(),
    datatable = run_datatable(),
    check = FALSE, # Results might differ slightly in class (tibble vs data.table)
    iterations = 5
  )
  print(res)
} else {
  message("Package 'bench' not installed. Skipping benchmark execution.")

  # Simple timing if bench is missing
  start_time <- Sys.time()
  invisible(run_dplyr())
  end_time <- Sys.time()
  cat("dplyr time:", end_time - start_time, "\n")

  start_time <- Sys.time()
  invisible(run_datatable())
  end_time <- Sys.time()
  cat("data.table time:", end_time - start_time, "\n")
}
