# 1. Check COW code overlap (sample)
message("Spine COWcode_a (supporter) unique values sample:")
sort(unique(spine$COWcode_a)) |> head(20) |> print()

message("Active supnum_cow unique values sample:")
sort(unique(active$supnum_cow)) |> head(20) |> print()

message("Spine COWcode_b (target) unique values sample:")
sort(unique(spine$COWcode_b)) |> head(20) |> print()

message("Active tarnum_cow unique values sample:")
sort(unique(active$tarnum_cow)) |> head(20) |> print()

# 2. Check year overlap
message("Spine year range:")
range(spine$year, na.rm = TRUE) |> print()

message("Active year range:")
range(active$year, na.rm = TRUE) |> print()

# 3. Check type of keys
message("Spine COWcode_a class:")
class(spine$COWcode_a) |> print()

message("Active supnum_cow class:")
class(active$supnum_cow) |> print()