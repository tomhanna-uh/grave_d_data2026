# Check supporter overlap (supnum_cow in active vs COWcode_a in spine)
message("Number of unique supporters in NAG active:")
length(unique(active$supnum_cow)) |> print()

message("Number of unique COWcode_a in spine:")
length(unique(spine$COWcode_a)) |> print()

message("Overlapping supporter codes (supnum_cow in active ∩ COWcode_a in spine):")
intersect(active$supnum_cow, spine$COWcode_a) |> sort() |> print()

# Same for target
message("Overlapping target codes (tarnum_cow in active ∩ COWcode_b in spine):")
intersect(active$tarnum_cow, spine$COWcode_b) |> sort() |> print()

# Check if any dyad matches (ignore year)
message("Number of dyad matches ignoring year:")
spine |>
        inner_join(active, by = c("COWcode_a" = "supnum_cow", "COWcode_b" = "tarnum_cow")) |>
        nrow() |> print()