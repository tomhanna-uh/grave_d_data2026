# Option 1: see if the column exists at all
"capital_dist_km" %in% names(spine)

# Option 2: look at the first few rows including the new column
spine |>
        select(COWcode_a, COWcode_b, capital_dist_km) |>
        head(10)

# Option 3: summary of distances (non-NA count tells you how many matches you got)
summary(spine$capital_dist_km)

# Option 4: total non-missing distances
sum(!is.na(spine$capital_dist_km))