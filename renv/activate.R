
local({

  # The version of renv to be used.
  version <- "1.0.0"

  # Load the renv package, installing it if necessary.
  if (!requireNamespace("renv", quietly = TRUE)) {

    # Define the repository to download from.
    repos <- c(CRAN = "https://cloud.r-project.org")

    # Try to download and install renv.
    message("Bootstrapping renv ", version, "...")
    utils::install.packages("renv", repos = repos, quiet = TRUE)

    if (!requireNamespace("renv", quietly = TRUE)) {
      stop("Failed to install renv: please install it manually.")
    }
  }

  # Load the renv package.
  renv::load()

})
