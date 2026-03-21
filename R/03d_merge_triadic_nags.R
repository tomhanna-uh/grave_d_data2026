# =============================================================================
# 03d_merge_triadic_nags.R
# Final production merge of Triadic NAG variables for H5 (and H4)
# =============================================================================
here::i_am("R/03d_merge_triadic_nags.R")

source(here::here("R", "00_packages.R"))
message("[03d] Starting final Triadic NAG merge...")

# ----------------------------------------------------------------------------
# 1. Load spine
# ----------------------------------------------------------------------------
spine <- readRDS(here("data", "spine_ideology_nags.rds")) |>
        mutate(across(c(COWcode_a, COWcode_b), as.integer))

# ----------------------------------------------------------------------------
# 2. Load and prepare triadic data
# ----------------------------------------------------------------------------
triadic <- read_csv(here("source_data", "triadic_data.csv"), show_col_types = FALSE) |>
        janitor::clean_names() |>
        mutate(
                tar_num_cow = as.integer(tar_num_cow),
                sup_num_cow = as.integer(sup_num_cow),
                year        = as.integer(year)
        )

# ----------------------------------------------------------------------------
# 3. Aggregate to dyad-year level (correct conditions for character data)
# ----------------------------------------------------------------------------
triadic_agg <- triadic |>
        group_by(sup_num_cow, tar_num_cow, year) |>
        summarise(
                # H5 core variable
                nags_nondem_objective = as.integer(any(nag_auth == "1" | nag_dict == "1" | 
                                                               nag_mil == "1" | nag_theo == "1", na.rm = TRUE)),
                nags_auth_support     = as.integer(any(nag_auth == "1", na.rm = TRUE)),
                
                # H4 NAG identity
                nags_ethnonationalist = as.integer(any(nagid_2 == "1", na.rm = TRUE)),
                nags_religious        = as.integer(any(nagid_3 == "1", na.rm = TRUE)),
                nags_leftist          = as.integer(any(nagid_4 == "1", na.rm = TRUE)),
                
                # Full NAG objectives
                nags_obj_topple       = as.integer(any(nag_obj_1 == "1", na.rm = TRUE)),
                nags_obj_regimechange = as.integer(any(nag_obj_2 == "1", na.rm = TRUE)),
                nags_obj_autonomy     = as.integer(any(nag_obj_3 == "1", na.rm = TRUE)),
                nags_obj_secession    = as.integer(any(nag_obj_4 == "1", na.rm = TRUE)),
                nags_obj_policy       = as.integer(any(nag_obj_5 == "1", na.rm = TRUE)),
                nags_obj_other        = as.integer(any(nag_obj_6 == "1", na.rm = TRUE)),
                
                .groups = "drop"
        )

# ----------------------------------------------------------------------------
# 4. Merge and zero-fill
# ----------------------------------------------------------------------------
spine_triadic <- spine |>
        left_join(triadic_agg,
                  by = c("COWcode_a" = "sup_num_cow",
                         "COWcode_b" = "tar_num_cow",
                         "year" = "year")) |>
        mutate(across(starts_with("nags_"), ~replace_na(., 0L)))

saveRDS(spine_triadic, here("data", "spine_ideology_nags_triadic.rds"))
message("[03d] Saved final spine_ideology_nags_triadic.rds")

# ----------------------------------------------------------------------------
# Quick check
# ----------------------------------------------------------------------------
message("nags_nondem_objective mean: ", round(mean(spine_triadic$nags_nondem_objective, na.rm = TRUE), 4))
print(colnames(spine_triadic)[grepl("nags_", colnames(spine_triadic))])