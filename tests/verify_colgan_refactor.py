
def check_duplicate_removal():
    f03 = open('R/03_build_grave_d_ideology.R').read()
    f06 = open('R/06_impute_controls.R').read()
    u_colgan = open('R/utils_colgan.R').read()

    # Check that colgan is loaded exactly once in util file
    assert 'colgan <- dplyr::as_tibble(data.table::fread(file = colgan_files[1]))' in u_colgan

    # Check that duplication is removed
    assert 'colgan_files <- list.files' not in f03
    assert 'colgan_files <- list.files' not in f06

    # Check refactored code exists
    assert 'colgan_raw <- load_colgan_data(apply_renames = FALSE)' in f03
    assert 'colgan <- load_colgan_data(apply_renames = TRUE)' in f06

    print('Static analysis checks passed. Redundant code successfully removed.')

check_duplicate_removal()
