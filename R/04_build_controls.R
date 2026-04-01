# =============================================================================
# 04_build_controls.R
# Merge control variables from multiple sources onto the ideology spine
# =============================================================================
source(here::here("R", "00_packages.R"))
message("[04] Starting controls merge...")

# ----------------------------------------------------------------------------
# 1. Load the NEW spine that includes the triadic NAG variables
# ----------------------------------------------------------------------------
spine_path <- here("data", "spine_ideology_nags_triadic.rds")
if (!file.exists(spine_path)) {
        stop("[04] spine_ideology_nags_triadic.rds not found.\nRun 03d_merge_triadic_nags.R first.")
}

spine <- readRDS(spine_path) |>
        mutate(across(c(COWcode_a, COWcode_b), as.integer))

message(sprintf("[04] Loaded NEW spine with triadic NAG vars: %d rows", nrow(spine)))
# -----------------------------------------------------------------------------
# 1. V-Dem (via R package, not flat file)
# -----------------------------------------------------------------------------
if (requireNamespace("vdemdata", quietly = TRUE)) {
        message("[04] Loading V-Dem from vdemdata package...")
        
        # Use any_of() throughout so the script survives version differences
        vdem_core <- c(
                "COWcode", "year",
                # Democracy & regime indices
                "v2x_polyarchy", "v2x_libdem", "v2x_partipdem", "v2x_delibdem",
                "v2x_egaldem", "v2x_regime", "v2x_regime_amb",
                # Executive access & type
                "v2x_ex_military", "v2x_ex_confidence", "v2x_ex_direlect",
                "v2x_ex_hereditary", "v2x_ex_party",
                # Neopatrimonialism & clientelism
                "v2x_neopat", "v2xnp_client",
                # Civil society & deliberation
                "v2x_frassoc_thick", "v2x_cspart",
                "v2dlreason", "v2dlcommon", "v2dlcountr", "v2dlencmps",
                # Constraints
                "v2x_jucon", "v2xlg_legcon",
                "v2juhcind", "v2juncind", "v2juhccomp", "v2jucomp", "v2jureview",
                # Corruption & rule of law
                "v2x_corr", "v2x_rule", "v2xcl_prpty", "v2x_gencl",
                "v2x_clpol", "v2x_clpriv", "v2xcs_ccsi",
                # Legislature
                "v2lgoppart",
                # State capacity & territory
                "v2stfisccap", "v2svstterr",
                # Media
                "v2mecenefi", "v2mecenefm",
                # Ideology legitimation (continuous)
                "v2exl_legitideol", "v2exl_legitperf", "v2exl_legitlead",
                "v2exl_legitratio",
                # Ideology type categorical probabilities (0-4)
                "v2exl_legitideolcr_0", "v2exl_legitideolcr_1", "v2exl_legitideolcr_2",
                "v2exl_legitideolcr_3", "v2exl_legitideolcr_4",
                # Power distribution by social group
                "v2pepwrses", "v2pepwrsoc", "v2xpe_exlsocgr",
                # Head of government
                "v2exhoshog", "v2exremhog", "v2exdjdshg", "v2exdfvthg",
                # Regime support groups (categorical probabilities 0-13)
                "v2regsupgroups_0", "v2regsupgroups_1", "v2regsupgroups_2",
                "v2regsupgroups_3", "v2regsupgroups_4", "v2regsupgroups_5",
                "v2regsupgroups_6", "v2regsupgroups_7", "v2regsupgroups_8",
                "v2regsupgroups_9", "v2regsupgroups_10", "v2regsupgroups_11",
                "v2regsupgroups_12", "v2regsupgroups_13",
                "v2regsupgroupssize", "v2regimpgroup",
                "v2reginfo", "v2regint", "v2regendtype",
                # NEW: Regime opposition groups size 
                "v2regoppgroupssize",
                # HOG removal probabilities (0-8)
                "v2exrmhgnp_0", "v2exrmhgnp_1", "v2exrmhgnp_2", "v2exrmhgnp_3",
                "v2exrmhgnp_4", "v2exrmhgnp_5", "v2exrmhgnp_6", "v2exrmhgnp_7",
                "v2exrmhgnp_8",
                # HOG control probabilities (0-8)
                "v2exctlhg_0", "v2exctlhg_1", "v2exctlhg_2", "v2exctlhg_3",
                "v2exctlhg_4", "v2exctlhg_5", "v2exctlhg_6", "v2exctlhg_7",
                "v2exctlhg_8",
                # Economic & social (e_ variables) -- names vary by vdemdata version
                "egdppc", "epop", # v12+ names
                "e_migdppc", "e_mipopula", # older names (any_of handles both)
                "e_cow_exports", "e_cow_imports",
                "e_total_fuel_income_pc", "e_total_oil_income_pc",
                "e_miurbani", "e_civil_war", "e_miinteco",
                "e_legparty", "e_autoc", "e_peaveduc"
        )
        
        vdem_data <- vdemdata::vdem |>
                as_tibble() |>
                select(any_of(vdem_core)) |>
                filter(!is.na(COWcode))
        
        # Harmonise to current V-Dem names (v12+)
        if ("e_migdppc" %in% names(vdem_data) && !"egdppc" %in% names(vdem_data)) {
                vdem_data <- vdem_data |> rename(egdppc = e_migdppc)
        }
        if ("e_mipopula" %in% names(vdem_data) && !"epop" %in% names(vdem_data)) {
                vdem_data <- vdem_data |> rename(epop = e_mipopula)
        }
        
        message(sprintf("[04] V-Dem: %d country-year rows, %d columns (now including v2regoppgroupssize)",
                        nrow(vdem_data), ncol(vdem_data)))
} else {
        warning("[04] vdemdata package not installed. V-Dem variables will be absent.")
        vdem_data <- NULL
}


# -----------------------------------------------------------------------------
# 2. CINC (National Material Capabilities)
# -----------------------------------------------------------------------------
cinc_files <- list.files(
        here("source_data", "controls", "cinc"),
        pattern = ".*\\.(csv|dta)$", full.names = TRUE, ignore.case = TRUE
)
if (length(cinc_files) > 0) {
        message(sprintf("[04] Found CINC file: %s", cinc_files[1]))
        if (grepl("\\.csv$", cinc_files[1])) {
                cinc_data <- as_tibble(data.table::fread(cinc_files[1]))
        } else {
                cinc_data <- haven::read_dta(cinc_files[1])
        }
        cinc_data <- cinc_data |> rename_with(tolower)
        if ("ccode"   %in% names(cinc_data)) cinc_data <- cinc_data |> rename(COWcode = ccode)
        if ("cowcode" %in% names(cinc_data)) cinc_data <- cinc_data |> rename(COWcode = cowcode)
        cinc_data <- cinc_data |> select(COWcode, year, cinc) |> filter(!is.na(cinc))
        message(sprintf("[04] CINC: %d country-year rows", nrow(cinc_data)))
} else {
        warning("[04] No CINC file found in source_data/controls/cinc/")
        cinc_data <- NULL
}

# -----------------------------------------------------------------------------
# 3. ATOP (Alliance Treaty Obligations and Provisions)
# -----------------------------------------------------------------------------
atop_path <- here("source_data", "atop", "atop5_1ddyr_NNA.csv")
if (file.exists(atop_path)) {
        atop_data <- as_tibble(data.table::fread(atop_path)) |>
                rename_with(tolower)
        if (all(c("statea", "stateb", "year") %in% names(atop_data))) {
                atop_data <- atop_data |>
                        rename(COWcode_a = statea, COWcode_b = stateb)
        }
        message(sprintf("[04] ATOP: %d rows x %d cols", nrow(atop_data), ncol(atop_data)))
} else {
        atop_files <- list.files(
                here("source_data", "atop"),
                pattern = ".*ddyr.*\\.csv$", full.names = TRUE, ignore.case = TRUE
        )
        if (length(atop_files) > 0) {
                atop_data <- as_tibble(data.table::fread(atop_files[1])) |>
                        rename_with(tolower)
                if (all(c("statea", "stateb", "year") %in% names(atop_data))) {
                        atop_data <- atop_data |>
                                rename(COWcode_a = statea, COWcode_b = stateb)
                }
                message(sprintf("[04] ATOP (fallback): %s | %d rows", basename(atop_files[1]), nrow(atop_data)))
        } else {
                warning("[04] atop5_1ddyr_NNA.csv not found in source_data/atop/")
                atop_data <- NULL
        }
}

# -----------------------------------------------------------------------------
# 4. COW World Religions Project
# -----------------------------------------------------------------------------
wrp_path <- here("source_data", "cow", "WRP_national.csv")
if (file.exists(wrp_path)) {
        wrp_data <- as_tibble(data.table::fread(wrp_path)) |> rename_with(tolower)
        if ("ccode"   %in% names(wrp_data)) wrp_data <- wrp_data |> rename(COWcode = ccode)
        if ("cowcode" %in% names(wrp_data)) wrp_data <- wrp_data |> rename(COWcode = cowcode)
        if ("state"   %in% names(wrp_data)) wrp_data <- wrp_data |> rename(COWcode = state)
        message(sprintf("[04] WRP religions: %d rows", nrow(wrp_data)))
} else {
        warning("[04] WRP_national.csv not found in source_data/cow/")
        wrp_data <- NULL
}

# -----------------------------------------------------------------------------
# 5. First Use of Violent Force (FUVF) - Caprioli & Trumbore
# -----------------------------------------------------------------------------
# Expected file: FUFv1.10.csv (or similar) in source_data/mids/
# Key variables: fuf (1 = first user of violent force), fufyear, fufjoin, midjoin
# Unit: country-year (initiator == 1 rows only in original; we keep all and
#        create a binary indicator for merge onto dyadic spine)
fuvf_files <- list.files(
        here("source_data", "mids"),
        pattern = ".*fuv.*\\.csv$", full.names = TRUE, ignore.case = TRUE
)
if (length(fuvf_files) > 0) {
        message(sprintf("[04] Found FUVF file: %s", fuvf_files[1]))
        fuvf_data <- as_tibble(data.table::fread(fuvf_files[1])) |>
                rename_with(tolower)
        # Standardise country code column
        if ("ccode"   %in% names(fuvf_data)) fuvf_data <- fuvf_data |> rename(COWcode = ccode)
        if ("cowcode" %in% names(fuvf_data)) fuvf_data <- fuvf_data |> rename(COWcode = cowcode)
        # Standardise year column
        if ("fufyear" %in% names(fuvf_data) && !"year" %in% names(fuvf_data)) {
                fuvf_data <- fuvf_data |> rename(year = fufyear)
        }
        # Create binary initiator flag and retain useful columns
        fuvf_data <- fuvf_data |>
                mutate(fuf_initiator = if_else(!is.na(fuf) & fuf == 1, 1L, 0L)) |>
                select(COWcode, year, fuf_initiator,
                       any_of(c("fuf", "endate", "fufjoin", "midjoin"))) |>
                filter(!is.na(COWcode), !is.na(year)) |>
                distinct(COWcode, year, .keep_all = TRUE)
        message(sprintf("[04] FUVF: %d country-year rows", nrow(fuvf_data)))
} else {
        warning("[04] No FUVF file found in source_data/mids/. Expected FUFv1.10.csv or similar.")
        fuvf_data <- NULL
}

# -----------------------------------------------------------------------------
# 6. Economic controls (source_data/econ/ subdirectories)
# -----------------------------------------------------------------------------

# 6a. Ross oil and gas
ross_files <- list.files(
        here("source_data", "econ", "ross_oil_gas"),
        pattern = ".*\\.(csv|dta)$", full.names = TRUE, ignore.case = TRUE
)
if (length(ross_files) > 0) {
        if (grepl("\\.csv$", ross_files[1])) {
                ross_data <- as_tibble(data.table::fread(ross_files[1]))
        } else {
                ross_data <- haven::read_dta(ross_files[1])
        }
        ross_data <- ross_data |> rename_with(tolower)
        if ("ccode"   %in% names(ross_data)) ross_data <- ross_data |> rename(COWcode = ccode)
        if ("cowcode" %in% names(ross_data)) ross_data <- ross_data |> rename(COWcode = cowcode)
        message(sprintf("[04] Ross: %d rows", nrow(ross_data)))
} else {
        ross_data <- NULL
}

# 6b. Maddison GDP
maddison_files <- list.files(
        here("source_data", "econ", "maddison"),
        pattern = ".*\\.(csv|dta|xlsx)$", full.names = TRUE, ignore.case = TRUE
)
if (length(maddison_files) > 0) {
        if (grepl("\\.csv$", maddison_files[1])) {
                maddison_data <- as_tibble(data.table::fread(maddison_files[1]))
        } else if (grepl("\\.dta$", maddison_files[1])) {
                maddison_data <- haven::read_dta(maddison_files[1])
        } else {
                maddison_data <- readxl::read_excel(maddison_files[1])
        }
        maddison_data <- maddison_data |> rename_with(tolower)
        if ("ccode"   %in% names(maddison_data)) maddison_data <- maddison_data |> rename(COWcode = ccode)
        if ("cowcode" %in% names(maddison_data)) maddison_data <- maddison_data |> rename(COWcode = cowcode)
        message(sprintf("[04] Maddison: %d rows", nrow(maddison_data)))
} else {
        maddison_data <- NULL
}

# 6c. SWIID inequality
swiid_files <- list.files(
        here("source_data", "econ", "swiid"),
        pattern = ".*\\.(csv|dta|rds)$", full.names = TRUE, ignore.case = TRUE
)
if (length(swiid_files) > 0) {
        if (grepl("\\.csv$", swiid_files[1])) {
                swiid_data <- as_tibble(data.table::fread(swiid_files[1]))
        } else if (grepl("\\.rds$", swiid_files[1])) {
                swiid_data <- readRDS(swiid_files[1])
        } else {
                swiid_data <- haven::read_dta(swiid_files[1])
        }
        swiid_data <- swiid_data |> rename_with(tolower)
        if ("ccode"   %in% names(swiid_data)) swiid_data <- swiid_data |> rename(COWcode = ccode)
        if ("cowcode" %in% names(swiid_data)) swiid_data <- swiid_data |> rename(COWcode = cowcode)
        message(sprintf("[04] SWIID: %d rows", nrow(swiid_data)))
} else {
        swiid_data <- NULL
}

# 6d. Fraser Institute black market exchange rates
fraser_path <- here("source_data", "econ", "fraser_institute", "black_market_exchange_rates.csv")
if (file.exists(fraser_path)) {
        fraser_data <- as_tibble(data.table::fread(fraser_path)) |> rename_with(tolower)
        if ("ccode"   %in% names(fraser_data)) fraser_data <- fraser_data |> rename(COWcode = ccode)
        if ("cowcode" %in% names(fraser_data)) fraser_data <- fraser_data |> rename(COWcode = cowcode)
        message(sprintf("[04] Fraser: %d rows", nrow(fraser_data)))
} else {
        fraser_data <- NULL
}

# 6e. Relational export dataset
export_files <- list.files(
        here("source_data", "econ", "relational_export_dataset"),
        pattern = ".*\\.(csv|dta)$", full.names = TRUE, ignore.case = TRUE
)
if (length(export_files) > 0) {
        if (grepl("\\.csv$", export_files[1])) {
                export_data <- as_tibble(data.table::fread(export_files[1]))
        } else {
                export_data <- haven::read_dta(export_files[1])
        }
        export_data <- export_data |> rename_with(tolower)
        message(sprintf("[04] Export data: %d rows", nrow(export_data)))
} else {
        export_data <- NULL
}

# -----------------------------------------------------------------------------
# 7. Merge all controls onto spine
# -----------------------------------------------------------------------------
spine_controls <- spine

# 7a. V-Dem (country-year -> both sides)
if (!is.null(vdem_data)) {
        spine_controls <- spine_controls |>
                left_join(
                        vdem_data |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)),
                        by = c("COWcode_a" = "COWcode", "year")
                ) |>
                left_join(
                        vdem_data |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)),
                        by = c("COWcode_b" = "COWcode", "year")
                )
        message("[04] Merged V-Dem (both sides).")
}

# 7b. CINC (country-year -> both sides)
if (!is.null(cinc_data)) {
        spine_controls <- spine_controls |>
                left_join(
                        cinc_data |> rename(cinc_a = cinc),
                        by = c("COWcode_a" = "COWcode", "year")
                ) |>
                left_join(
                        cinc_data |> rename(cinc_b = cinc),
                        by = c("COWcode_b" = "COWcode", "year")
                )
        message("[04] Merged CINC (both sides).")
}

# 7c. ATOP (dyad-year)
if (!is.null(atop_data) &&
    all(c("COWcode_a", "COWcode_b", "year") %in% names(atop_data))) {
        atop_merge <- atop_data |>
                distinct(COWcode_a, COWcode_b, year, .keep_all = TRUE)
        spine_controls <- spine_controls |>
                left_join(atop_merge, by = c("COWcode_a", "COWcode_b", "year"))
        message(sprintf("[04] Merged ATOP: %d alliance columns.",
                        ncol(atop_merge) - 3))
} else if (!is.null(atop_data)) {
        message("[04] ATOP loaded but COWcode_a/COWcode_b/year keys not found. Skipping merge.")
}


# Fill NA ATOP values with 0 for dyads with no alliance
# Logic: absence from ATOP means no alliance exists, not missing data.
# All binary/count alliance indicators should be 0, not NA.
atop_fill_cols <- intersect(
        c("atopally", "defense", "offense", "neutral", "nonagg", "consul",
          "shareob", "bilatno", "multino", "number", "asymm"),
        names(spine_controls)
)
if (length(atop_fill_cols) > 0) {
        spine_controls <- spine_controls |>
                mutate(across(all_of(atop_fill_cols), ~ replace_na(., 0)))
        message(sprintf("[04] Filled %d ATOP columns: NA -> 0 for non-allied dyads.",
                        length(atop_fill_cols)))
}


# 7d. WRP religions (country-year -> both sides)
# WRP data is released at 5-year intervals (1945, 1950, ..., 2010).
# Interpolation method: Linear interpolation between observed values.
# For years before the first observation, the earliest value is carried
# backward. For years after the last observation (post-2010), the last
# value is carried forward (LOCF). This assumes religious demographic
# change is gradual and roughly linear between census waves.
if (!is.null(wrp_data)) {
        wrp_cols <- intersect(
                c("COWcode", "year", "chrstgenpct", "islmgenpct", "budgenpct", "hindgenpct"),
                names(wrp_data)
        )
        if (length(wrp_cols) >= 3) {
                wrp_clean <- wrp_data |>
                        select(all_of(wrp_cols)) |>
                        distinct(COWcode, year, .keep_all = TRUE)
                
                # Determine the religion percentage columns (everything except keys)
                relig_cols <- setdiff(wrp_cols, c("COWcode", "year"))
                
                # Get the full range of years in the spine
                all_years <- sort(unique(spine_controls$year))
                all_cow   <- sort(unique(c(spine_controls$COWcode_a, spine_controls$COWcode_b)))
                
                # Expand to full country-year panel
                wrp_panel <- tidyr::expand_grid(COWcode = all_cow, year = all_years) |>
                        left_join(wrp_clean, by = c("COWcode", "year"))
                
                # Linear interpolation + carry forward/backward per country
                # approx(..., rule = 2) extrapolates using the nearest observed value
                # at both ends (LOCF forward, earliest-carried backward)
                wrp_interp <- wrp_panel |>
                        arrange(COWcode, year) |>
                        group_by(COWcode) |>
                        mutate(across(
                                all_of(relig_cols),
                                ~ if (sum(!is.na(.)) >= 2) {
                                        approx(year[!is.na(.)], .[!is.na(.)], xout = year, rule = 2)$y
                                } else if (sum(!is.na(.)) == 1) {
                                        replace_na(., .[!is.na(.)][1])
                                } else {
                                        .
                                }
                        )) |>
                        ungroup()
                
                message(sprintf(
                        "[04] WRP interpolated: %d country-years (from %d observed 5-year intervals).",
                        sum(!is.na(wrp_interp[[relig_cols[1]]])),
                        sum(!is.na(wrp_clean[[relig_cols[1]]]))
                ))
                
                # Merge interpolated WRP onto both sides
                spine_controls <- spine_controls |>
                        left_join(
                                wrp_interp |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)),
                                by = c("COWcode_a" = "COWcode", "year")
                        ) |>
                        left_join(
                                wrp_interp |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)),
                                by = c("COWcode_b" = "COWcode", "year")
                        )
                message("[04] Merged WRP religions (both sides, interpolated).")
        }
}


# 7e. FUVF (country-year -> Side A only, since it marks who initiated)
if (!is.null(fuvf_data)) {
        spine_controls <- spine_controls |>
                left_join(
                        fuvf_data |> select(COWcode, year, fuf_initiator),
                        by = c("COWcode_a" = "COWcode", "year")
                )
        message("[04] Merged FUVF (Side A).")
}

# 7f-7j. Remaining economic datasets
# Ross Oil and Gas
if (!is.null(ross_data)) {
        ross_merge <- ross_data |>
                mutate(is_petro_state = if_else(oil_income_pc > 100, 1L, 0L)) |>
                select(COWcode, year, oil_income_pc, is_petro_state) |>
                distinct(COWcode, year, .keep_all = TRUE)

        spine_controls <- spine_controls |>
                left_join(
                        ross_merge |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)),
                        by = c("COWcode_a" = "COWcode", "year")
                ) |>
                left_join(
                        ross_merge |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)),
                        by = c("COWcode_b" = "COWcode", "year")
                )
        message("[04] Merged Ross oil_income_pc and is_petro_state (both sides).")
}

# Maddison GDP
if (!is.null(maddison_data)) {
        gdp_candidates <- intersect(c("rgdpnapc", "gdppc"), names(maddison_data))
        maddison_merge <- maddison_data |>
                mutate(log_gdp_pc = log(coalesce(!!!syms(gdp_candidates)))) |>
                select(COWcode, year, log_gdp_pc) |>
                distinct(COWcode, year, .keep_all = TRUE)

        spine_controls <- spine_controls |>
                left_join(
                        maddison_merge |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)),
                        by = c("COWcode_a" = "COWcode", "year")
                ) |>
                left_join(
                        maddison_merge |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)),
                        by = c("COWcode_b" = "COWcode", "year")
                )
        message("[04] Merged Maddison log_gdp_pc (both sides).")
}

# SWIID Inequality
if (!is.null(swiid_data)) {
        swiid_merge <- swiid_data |>
                select(COWcode, year, gini_disp) |>
                distinct(COWcode, year, .keep_all = TRUE)

        spine_controls <- spine_controls |>
                left_join(
                        swiid_merge |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)),
                        by = c("COWcode_a" = "COWcode", "year")
                ) |>
                left_join(
                        swiid_merge |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)),
                        by = c("COWcode_b" = "COWcode", "year")
                )
        message("[04] Merged SWIID gini_disp (both sides).")
}

# Fraser Institute Black Market Rates
if (!is.null(fraser_data)) {
        fraser_merge <- fraser_data |>
                select(COWcode, year, bmr) |>
                distinct(COWcode, year, .keep_all = TRUE)

        spine_controls <- spine_controls |>
                left_join(
                        fraser_merge |> rename_with(~ paste0(., "_a"), .cols = -c(COWcode, year)),
                        by = c("COWcode_a" = "COWcode", "year")
                ) |>
                left_join(
                        fraser_merge |> rename_with(~ paste0(., "_b"), .cols = -c(COWcode, year)),
                        by = c("COWcode_b" = "COWcode", "year")
                )
        message("[04] Merged Fraser bmr (both sides).")
}

# Relational Export Dataset (dyadic)
if (!is.null(export_data)) {
        export_merge <- export_data |>
                select(COWcode_a, COWcode_b, year, exp_total) |>
                distinct(COWcode_a, COWcode_b, year, .keep_all = TRUE)

        spine_controls <- spine_controls |>
                left_join(export_merge, by = c("COWcode_a", "COWcode_b", "year"))
        message("[04] Merged Export exp_total (dyadic).")
}

# -----------------------------------------------------------------------------
# 8. Construct GRAVE-D sidea_* ideology & support variables
# -----------------------------------------------------------------------------
if ("v2exl_legitideol_a" %in% names(spine_controls)) {
        spine_controls <- spine_controls |>
                mutate(
                        # Overall ideology-based legitimation
                        sidea_revisionist_domestic = v2exl_legitideol_a,
                        
                        # Sub-types mapped to v2exl_legitideolcr categories
                        # 0=Nationalist, 1=Socialist, 2=Restorative, 3=Separatist, 4=Religious
                        sidea_nationalist_revisionist_domestic = if ("v2exl_legitideolcr_0_a" %in% names(spine_controls)) v2exl_legitideolcr_0_a else NA_real_,
                        sidea_socialist_revisionist_domestic   = if ("v2exl_legitideolcr_1_a" %in% names(spine_controls)) v2exl_legitideolcr_1_a else NA_real_,
                        sidea_reactionary_revisionist_domestic = if ("v2exl_legitideolcr_2_a" %in% names(spine_controls)) v2exl_legitideolcr_2_a else NA_real_,
                        sidea_separatist_revisionist_domestic  = if ("v2exl_legitideolcr_3_a" %in% names(spine_controls)) v2exl_legitideolcr_3_a else NA_real_,
                        sidea_religious_revisionist_domestic   = if ("v2exl_legitideolcr_4_a" %in% names(spine_controls)) v2exl_legitideolcr_4_a else NA_real_,
                        
                        # Personalist/charismatic leader legitimation
                        sidea_dynamic_leader = v2exl_legitlead_a
                )
        message("[04] Built sidea_revisionist_domestic and sub-type variables from V-Dem.")
} else {
        message("[04] V-Dem legitimation columns not found; skipping sidea_* ideology.")
}

# Support group variables
if ("v2pepwrses_a" %in% names(spine_controls)) {
        spine_controls <- spine_controls |>
                mutate(
                        sidea_party_elite_support    = v2pepwrses_a,
                        sidea_ethnic_racial_support  = v2pepwrsoc_a,
                        sidea_rural_worker_support   = v2x_cspart_a,
                        sidea_military_support       = if ("cinc_a" %in% names(spine_controls)) cinc_a else NA_real_,
                        sidea_religious_support      = if ("v2regsupgroups_7_a" %in% names(spine_controls)) v2regsupgroups_7_a else NA_real_,
                        sidea_winning_coalition_size = v2dlreason_a
                )
        message("[04] Built sidea_*_support variables.")
} else {
        message("[04] V-Dem power distribution columns not found; skipping support vars.")
}



# -----------------------------------------------------------------------------
# 9. Derived variables
# -----------------------------------------------------------------------------
spine_controls <- spine_controls |>
        mutate(
                targets_democracy = if_else(
                        "v2x_libdem_b" %in% names(spine_controls) & !is.na(v2x_libdem_b),
                        if_else(v2x_libdem_b >= 0.5, 1L, 0L),
                        NA_integer_
                ),
                cold_war = if_else(year >= 1947 & year <= 1991, 1L, 0L)
        )

message(sprintf(
        "[04] spine_controls: %d rows x %d cols",
        nrow(spine_controls), ncol(spine_controls)
))

# -----------------------------------------------------------------------------
# 10. Capitals distance variable
# -----------------------------------------------------------------------------
capdist <- data.table::fread(here("source_data", "gleditsch", "capdist.csv"))
names(capdist) <- tolower(names(capdist))

gw_to_cow_overrides <- c(
        "54" = 54L, "55" = 55L, "56" = 56L, "57" = 57L, "58" = 58L, "60" = 60L,
        "221" = 221L, "223" = 223L, "232" = 232L, "255" = 260L, "331" = 331L,
        "403" = 403L, "563" = 563L, "564" = 564L, "591" = 591L, "679" = 678L,
        "711" = 711L, "730" = 730L, "816" = 816L, "935" = 935L, "983" = 983L,
        "986" = 986L, "987" = 987L, "990" = 990L
)

capdist$COWcode_a <- countrycode::countrycode(
        capdist$numa, "gwn", "cown", custom_match = gw_to_cow_overrides
)
capdist$COWcode_b <- countrycode::countrycode(
        capdist$numb, "gwn", "cown", custom_match = gw_to_cow_overrides
)

capdist <- capdist |>
        filter(!is.na(COWcode_a), !is.na(COWcode_b)) |>
        select(COWcode_a, COWcode_b, capital_dist_km = kmdist) |>
        distinct(COWcode_a, COWcode_b, .keep_all = TRUE)




spine_controls <- spine_controls |>
        left_join(capdist, by = c("COWcode_a", "COWcode_b"))


# -----------------------------------------------------------------------------
# 10b. Clean up duplicated Target/Supporter columns
# Keep .x (from spine) as authoritative, drop .y
# -----------------------------------------------------------------------------
spine_controls <- spine_controls |>
        rename(
                Target    = Target.x,
                Supporter = Supporter.x
        ) |>
        select(-any_of(c("Target.y", "Supporter.y")))

# 11. Save
saveRDS(spine_controls, here("data", "spine_controls.rds"))
message("[04_build_controls.R] Saved: data/spine_controls.rds")
message("[04_build_controls.R] Done.")

