# GRAVE-D Data 2026

**GRAVE-D Protocol: Master Dyadic Dataset Builder**

**Project:** From Cooperation to Control: Authoritarian Leadership Politics & International Conflict  
**Author:** Tom Hanna  
**ORCID:** 0000-0002-8054-0335  
**Affiliation:** University of Houston, Department of Political Science  
**License:** [CC BY-NC-SA 4.0](http://creativecommons.org/licenses/by-nc-sa/4.0/)  
**Codebook Version:** GRAVE-D Master Dyadic Codebook v 1.0 (Last Updated: February 13, 2026)

---

## Overview

This repository contains the data assembly pipeline for the **GRAVE-D** (Grand Revisionism And Violence Event — Dyadic) dataset. It builds the master dyadic dataset used across multiple research projects, most notably:

- [autocracy_conflict_signaling](https://github.com/tomhanna-uh/autocracy_conflict_signaling) — Rational vs. Messianic Autocrat conflict signaling analysis

The dataset is a **directed dyad-year** panel covering 1946–2020. The unit of analysis is the behavior of Sender (Country A) toward Target (Country B) in a given year.

---

## Dataset Structure

| Dimension | Description |
|---|---|
| **Unit** | Directed Dyad-Year (Country A → Country B) |
| **Time Coverage** | 1946–2020 |
| **Spine** | FBIC (Foreign Bilateral Integration Capacity) dataset |
| **Output File** | `GRAVE_D_Master_with_Leaders.csv` |

---

## Variable Groups (GRAVE-D Codebook v 1.0)

### 1. Identification Variables

| Variable | Source | Description |
|---|---|---|
| `COWcode_a` | Correlates of War | Sender ID. Derived from `iso3a` in the FBIC spine. |
| `COWcode_b` | Correlates of War | Target ID. Derived from `iso3b` in the FBIC spine. |
| `year` | Various | Observation year (1946–2020). |
| `unregiona` | UN GeoScheme | Geographic region of Country A (Sender). |
| `unregionb` | UN GeoScheme | Geographic region of Country B (Target). |

### 2. FBIC Connectivity & "Bandwidth" (Dyadic Spine)

Source: Foreign Bilateral Integration Capacity (FBIC) Dataset.

| Variable | Source | Description |
|---|---|---|
| `bandwidth` | FBIC | Total Bandwidth. Composite index of total dyadic connectivity. |
| `economicbandwidth` | FBIC | Economic Bandwidth. Trade volume, FDI flows, economic agreements. |
| `politicalbandwidth` | FBIC | Political Bandwidth. Diplomatic connectedness. |
| `securitybandwidth` | FBIC | Security Bandwidth. Military-to-military ties, defense pacts, arms trade. |
| `socialbandwidth` | FBIC | Social Bandwidth. People-to-people exchanges, tourism, migration. |

### 3. Conflict & Targeting Outcomes

Derived from MIDs v4.0 and GRAVE-D feature engineering scripts.

| Variable | Source | Description |
|---|---|---|
| `hihosta` | MIDs v4.0 | Highest Hostility Level (Side A). Ordinal 1–5; ≥2 = MID initiated. |
| `mid_initiated` | Derived | Binary: 1 if `hihosta` ≥ 2. |
| `targets_democracy` | Derived | Binary: 1 if `v2x_libdem_b` ≥ 0.5. |
| `dyad` | Derived | Unique dyad identifier (COWcode_a × COWcode_b). |

### 4. Democracy & Regime Variables

| Variable | Source | Description |
|---|---|---|
| `v2x_libdem_a` | V-Dem | Liberal Democracy Score — Sender (0=Autocracy, 1=Democracy). |
| `v2x_libdem_b` | V-Dem | Liberal Democracy Score — Target (0=Autocracy, 1=Democracy). |
| `v2exl_legitideol_a/b` | V-Dem | Ideological Legitimation score. |
| `v2exl_legitlead_a/b` | V-Dem | Personalist Legitimation score. |
| `v2exl_legitperf_a/b` | V-Dem | Performance Legitimation score. |

### 5. GRAVE-D Leadership Ideology Variables

| Variable | Source | Description |
|---|---|---|
| `sidea_revisionist_domestic` | GRAVE-D | Composite revisionist domestic ideology score (Sender). |
| `sidea_nationalist_revisionist_domestic` | GRAVE-D | Nationalist revisionist ideology. |
| `sidea_socialist_revisionist_domestic` | GRAVE-D | Socialist revisionist ideology. |
| `sidea_religious_revisionist_domestic` | GRAVE-D | Religious revisionist ideology. |
| `sidea_reactionary_revisionist_domestic` | GRAVE-D | Reactionary revisionist ideology. |
| `sidea_dynamic_leader` | GRAVE-D | Dynamic leadership proxy (Messianic Autocrat). |

### 6. GRAVE-D Support Group Variables

| Variable | Source | Description |
|---|---|---|
| `sidea_religious_support` | GRAVE-D | Regime support from religious groups. |
| `sidea_party_elite_support` | GRAVE-D | Regime support from party elites. |
| `sidea_rural_worker_support` | GRAVE-D | Regime support from rural/worker groups. |
| `sidea_military_support` | GRAVE-D | Regime support from military. |
| `sidea_ethnic_racial_support` | GRAVE-D | Regime support from ethnic/racial groups. |
| `sidea_winning_coalition_size` | V-Dem/BdM | Winning coalition size (Selectorate Theory). |

### 7. Control Variables

| Variable | Source | Description |
|---|---|---|
| `sidea_national_military_capabilities` | COW (CINC) | National military capabilities — Sender. |
| `sideb_national_military_capabilities` | COW (CINC) | National military capabilities — Target. |
| `log_gdp_pc_a/b` | WDI/Maddison | Log GDP per Capita. Standard control for development. |
| `milex2011usdmila/b` | SIPRI/COW | Military Expenditure. Total military spending in constant 2011 USD. |
| `unified_corruption_a/b` | V-Dem/WGI | Unified Corruption Index (0=Clean, 1=Corrupt). |
| `is_petro_state_a/b` | Ross/WDI | Petro-State Dummy (1 if Oil/Gas Wealth > Threshold). |
| `reg_trans_a/b` | V-Dem | Regime Transition. Years since the last major regime change. |

### 8. Conflict Potential Index

| Variable | Source | Description |
|---|---|---|
| `conflict_potential_index` | Derived | Composite index combining CINC ratio, democracy gap, and alliance absence into a single conflict potential index. |

---

## Repository Structure

```
grave_d_data2026/
├── README.md
├── grave_d_data2026.Rproj
├── .gitignore
├── run_all.R                          # Master pipeline: run scripts in order
├── R/
│   ├── 00_packages.R                 # All library() calls
│   ├── 01_build_fbic_spine.R         # Build directed dyad-year spine from FBIC
│   ├── 02_build_conflict.R           # Merge MIDs v4.0 conflict outcomes
│   ├── 03_build_grave_d_ideology.R   # Merge GRAVE-D ideology & support group vars
│   ├── 04_build_controls.R           # Merge V-Dem, COW CINC, WDI controls
│   ├── 05_merge_master.R             # Assemble GRAVE_D_Master_with_Leaders.csv
│   └── 06_validate_export.R          # Validation checks and CSV export
├── source_data/                       # gitignored — place raw source files here
│   ├── fbic/                         # FBIC dataset files
│   ├── mids/                         # MIDs v4.0 files
│   ├── vdem/                         # V-Dem dataset files
│   ├── cow/                          # COW CINC files
│   ├── grave_d/                      # GRAVE-D coding files
│   └── wdi/                          # World Bank WDI files
├── output/                            # gitignored — assembled dataset output
│   └── GRAVE_D_Master_with_Leaders.csv
└── docs/
    ├── _quarto.yml
    └── codebook.qmd                  # Rendered GRAVE-D Codebook v 1.0
```

---

## Data Sources

| Source | Description | Location |
|---|---|---|
| **FBIC** | Foreign Bilateral Integration Capacity dataset — dyadic spine | `source_data/fbic/` |
| **MIDs v4.0** | Militarized Interstate Disputes v4.0 | `source_data/mids/` |
| **V-Dem** | Varieties of Democracy — democracy, legitimation, corruption | `source_data/vdem/` |
| **COW CINC** | Correlates of War National Material Capabilities | `source_data/cow/` |
| **GRAVE-D** | Grand Revisionism And Violence Event coding | `source_data/grave_d/` |
| **WDI/Maddison** | World Bank WDI + Maddison Project GDP per capita | `source_data/wdi/` |
| **SIPRI/COW** | Military expenditure data | `source_data/cow/` |
| **Ross/WDI** | Oil/Gas wealth for petro-state dummy | `source_data/wdi/` |

All source data files are **gitignored** and must be placed in `source_data/` before running the pipeline.

---

## Pipeline Scripts

The data production pipeline consists of six R scripts in the `R/` directory,
run sequentially:

| Script | Purpose |
|--------|---------|
| `00_packages.R` | Load and attach all required R packages. |
| `01_build_fbic_spine.R` | Build the directed dyad-year spine from FBIC bandwidth data. |
| `02_build_conflict.R` | Merge MID conflict variables onto the spine. |
| `03_build_grave_d_ideology.R` | Merge Archigos, Colgan, and global leader ideology data. |
| `04_build_controls.R` | Merge V-Dem (~100 variables via `vdemdata` package), CINC, ATOP alliances, WRP religion (with linear interpolation), FUVF first use of force, and economic controls. ATOP non-allied dyads are zero-filled. |
| `05_build_master.R` | Assemble final dataset: merge all intermediates, compute revisionist potential (Z-score composite of ideology, democratic constraint, and ideological extremity), derive conflict and religion distance variables, and export. Produces both `GRAVE_D_Master.csv` and `GRAVE_D_Master_with_Leaders.csv` (with Side B leader data). |
| `06_impute_controls.R` | Targeted imputation for scattered missing data. Interpolates within country-year panels (linear interpolation + carry forward/backward), applies regional-year median fill for countries with no coverage, then recomputes all derived variables from the imputed base data. Excludes structurally missing data (leader variables, Colgan, ATOP identifiers, internet censorship). |

markdown
## NAG-Specific Builds (2026)
- `03b_build_nags.R`: creates `nags_any_support`, `nags_active_support`, `nags_training` (camps bundled), `nags_arms`, `nags_funds`, `nags_troops`, `nags_support_count`.  
- `02b_build_nonstate_conflict.R`: adds monadic UCDP non-state conflict controls (`nonstate_conflict_a/b` etc.) for robustness.  
Run order unchanged; NAG variables zero-filled and ready for signaling models.

### Running the pipeline

```r
# From the project root in R:
source("R/00_packages.R")
source("R/01_build_fbic_spine.R")
source("R/02_build_conflict.R")
source("R/03_build_grave_d_ideology.R")
source("R/04_build_controls.R")
source("R/05_build_master.R")
source("R/06_impute_controls.R")
```

Or step by step:

```r
# Step 1: Load packages
source("R/00_packages.R")

# Step 2: Build FBIC spine
source("R/01_build_fbic_spine.R")

# Step 3: Merge conflict outcomes
source("R/02_build_conflict.R")

# Step 4: Merge GRAVE-D ideology & support vars
source("R/03_build_grave_d_ideology.R")

# Step 5: Merge control variables
source("R/04_build_controls.R")

# Step 6: Assemble master dataset
source("R/05_merge_master.R")

# Step 7: Validate and export
source("R/06_validate_export.R")
```

---

## Output

The pipeline produces:

- `output/GRAVE_D_Master_with_Leaders.csv` — The master dyadic dataset for use in analysis repositories

This file should be copied into the `data/` directory of downstream analysis repositories (e.g., `autocracy_conflict_signaling`).

---

## Related Repositories

- [autocracy_conflict_signaling](https://github.com/tomhanna-uh/autocracy_conflict_signaling) — Primary analysis repo consuming this dataset
- [2025_grave_d_conflict](https://github.com/tomhanna-uh/2025_grave_d_conflict) — Prior analysis version
- [2024_Research_Conflict_Ideology](https://github.com/tomhanna-uh/2024_Research_Conflict_Ideology) — Original conflict ideology models

---

## Citation

Hanna, Tom. GRAVE-D Data 2026: Master Dyadic Dataset Builder. Working repository, University of Houston, 2026.

Please be sure to cite original data sources listed in source_data.md

---

## License

This work is licensed under a [Creative Commons Attribution-NonCommercial-ShareAlike 4.0 International License](http://creativecommons.org/licenses/by-nc-sa/4.0/).
