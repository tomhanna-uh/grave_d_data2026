# Compare variable sets in old.csv vs new.csv

library(here)
library(tidyverse)

here::i_am("diagnostic/check_changes.R")

# 1. Read the two versions
old <- read_csv(here("ready_data","old.csv"), show_col_types = FALSE)
new <- read_csv(here("ready_data","new.csv"), show_col_types = FALSE)

# 2. Get variable name sets
old_vars <- colnames(old)
new_vars <- colnames(new)

# 3. Variables that are NEW in new.csv (not in old.csv)
new_only <- setdiff(new_vars, old_vars)

# 4. Variables that are LOST (in old.csv but missing from new.csv)
lost <- setdiff(old_vars, new_vars)

# 5. Print a compact summary
cat("=== New variables (in new.csv only) ===\n")
if (length(new_only) == 0) {
        cat("None\n\n")
} else {
        print(new_only)
        cat("\n")
}

cat("=== Lost variables (in old.csv but not in new.csv) ===\n")
if (length(lost) == 0) {
        cat("None\n\n")
} else {
        print(lost)
        cat("\n")
}

# Optional: counts
cat("Total vars in old.csv:", length(old_vars), "\n")
cat("Total vars in new.csv:", length(new_vars), "\n")
