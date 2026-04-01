# =============================================================================
# utils_colgan.R
# Shared utility functions for loading and standardizing Colgan leader data.
# =============================================================================

#' Load and standardize Colgan leader data
#'
#' This function finds the Colgan dataset in `source_data/colgan/`, reads it
#' according to its file extension (CSV, TSV, DTA, XLSX), standardizes column
#' names to lowercase, standardizes the COW code column, and optionally applies
#' standard Colgan variable renames.
#'
#' @param apply_renames Logical. If TRUE, renames specific columns (obsid, leader, etc.)
#'   to include a `_colgan` suffix to avoid conflicts when merging. Default is TRUE.
#' @return A tibble with the Colgan data, or NULL if no file is found.
load_colgan_data <- function(apply_renames = TRUE) {
        colgan_files <- list.files(
                here::here("source_data", "colgan"),
                pattern = ".*\\.(csv|tsv|dta|xlsx)$",
                full.names = TRUE,
                ignore.case = TRUE
        )

        if (length(colgan_files) == 0) {
                return(NULL)
        }

        # Read based on extension
        file_ext <- tolower(tools::file_ext(colgan_files[1]))

        if (file_ext == "csv") {
                colgan <- dplyr::as_tibble(data.table::fread(file = colgan_files[1]))
        } else if (file_ext == "tsv") {
                colgan <- readr::read_tsv(colgan_files[1], show_col_types = FALSE)
        } else if (file_ext == "dta") {
                colgan <- haven::read_dta(colgan_files[1])
        } else if (file_ext %in% c("xls", "xlsx")) {
                colgan <- readxl::read_excel(colgan_files[1])
        } else {
                stop("Unsupported file type for Colgan data.")
        }

        # Standardize basic column names
        colgan <- colgan |> dplyr::rename_with(tolower)

        # Standardize COWcode
        if ("ccode" %in% names(colgan)) {
                colgan <- colgan |> dplyr::rename(COWcode = ccode)
        } else if ("cowcode" %in% names(colgan)) {
                colgan <- colgan |> dplyr::rename(COWcode = cowcode)
        } else if ("country_code_cow" %in% names(colgan)) {
                colgan <- colgan |> dplyr::rename(COWcode = country_code_cow)
        }

        # Apply standard Colgan renames if requested
        if (apply_renames) {
                colgan_renames <- c(
                        obsid_colgan = "obsid",
                        leader_colgan = "leader",
                        startdate_colgan = "startdate",
                        enddate_colgan = "enddate",
                        entry_colgan = "entry",
                        prevtimesinoffice_colgan = "prevtimesinoffice",
                        posttenurefate_colgan = "posttenurefate",
                        gender_colgan = "gender"
                )

                # Only rename columns that actually exist in the data
                existing_renames <- colgan_renames[colgan_renames %in% names(colgan)]
                if (length(existing_renames) > 0) {
                        colgan <- colgan |> dplyr::rename(!!!existing_renames)
                }
        }

        return(colgan)
}
