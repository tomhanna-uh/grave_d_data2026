has_variation <- sapply(grave_d_leaders, function(x) {
        vals <- unique(x[!is.na(x)])
        length(vals) > 1
})

# which columns fail that condition?
constant_or_na <- names(grave_d_leaders)[!has_variation]

constant_or_na