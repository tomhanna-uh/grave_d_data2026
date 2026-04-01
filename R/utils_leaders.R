# =============================================================================
# utils_leaders.R
# Shared utility functions for leader-level data processing.
# =============================================================================

#' Load a leader dataset from a specified directory.
#'
#' @param dir_path Directory containing the data file.
#' @param pattern_str Regex pattern to match the file.
#' @param name_str Name of the dataset for logging purposes.
#' @return A tibble with standard lowercase column names, or NULL if not found.
load_leader_data <- function(dir_path, pattern_str, name_str) {
        files <- list.files(
                dir_path,
                pattern = pattern_str,
                full.names = TRUE,
                ignore.case = TRUE
        )

        if (length(files) == 0) {
                warning(sprintf("No %s files found in %s.", name_str, dir_path))
                return(NULL)
        }

        message(sprintf("Found %s file: %s", name_str, files[1]))
        if (grepl("\\.csv$", files[1], ignore.case = TRUE)) {
                raw_data <- as_tibble(data.table::fread(file = files[1]))
        } else if (grepl("\\.tsv$", files[1], ignore.case = TRUE)) {
                raw_data <- read_tsv(files[1], show_col_types = FALSE)
        } else if (grepl("\\.dta$", files[1], ignore.case = TRUE)) {
                raw_data <- haven::read_dta(files[1])
        } else {
                raw_data <- readxl::read_excel(files[1])
        }

        raw_data <- raw_data |> rename_with(tolower)
        message(sprintf("%s raw: %d rows x %d cols", name_str, nrow(raw_data), ncol(raw_data)))

        return(raw_data)
}

#' Standardize COW code columns across sources
#'
#' @param df A dataframe.
#' @return A dataframe with standardized 'COWcode' column.
standardize_cowcode <- function(df) {
        if (is.null(df)) return(NULL)

        if ("country_code_cow" %in% names(df)) {
                df <- df |> rename(COWcode = country_code_cow)
        } else if ("cowcode" %in% names(df)) {
                df <- df |> rename(COWcode = cowcode)
        } else if ("ccode" %in% names(df)) {
                df <- df |> rename(COWcode = ccode)
        }
        df
}

#' Expand Archigos data to a country-year panel.
#'
#' @param archigos_raw Standardized Archigos dataset.
#' @return A distinct country-year dataset, or NULL on error.
expand_archigos_to_cy <- function(archigos_raw) {
        if (is.null(archigos_raw) || !("COWcode" %in% names(archigos_raw))) {
                return(NULL)
        }

        if (all(c("startdate", "enddate") %in% names(archigos_raw))) {
                archigos_cy <- archigos_raw |>
                        mutate(
                                start_yr = as.integer(format(as.Date(startdate), "%Y")),
                                end_yr   = as.integer(format(as.Date(enddate), "%Y"))
                        ) |>
                        filter(!is.na(start_yr), !is.na(end_yr)) |>
                        mutate(year = purrr::map2(start_yr, end_yr, seq)) |>
                        tidyr::unnest(year) |>
                        select(-start_yr, -end_yr)
        } else if ("year" %in% names(archigos_raw)) {
                archigos_cy <- archigos_raw
        } else {
                warning("Archigos has no startdate/enddate or year column.")
                return(NULL)
        }

        archigos_cy <- archigos_cy |>
                arrange(COWcode, year, desc(startdate)) |>
                distinct(COWcode, year, .keep_all = TRUE)

        return(archigos_cy)
}
