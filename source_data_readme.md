# source_data/ Directory Guide

This directory contains all external source datasets used by the
GRAVE-D data production pipeline (`grave_d_data2026`). Each subdirectory
holds one logical data source. Files here are **not** produced by the
pipeline — they are inputs only.

> **Git policy:** `source_data/` is listed in `.gitignore`.
> You must populate these directories manually before running the
> pipeline scripts (`R/01_build_fbic_spine.R` through `R/05_build_master.R`).

---

## Directory Layout

## Directory Layout

- **source_data/**
  - **archigos/**
    - `archigos.tsv`
  - **atop/**
    - `atop5_1ddyr_NNA.csv`
  - **colgan/**
    - (Colgan leader data — .dta or .csv)
  - **controls/**
    - **cinc/**
      - (NMC / CINC file — .csv or .dta)
  - **cow/**
    - `dyadic_mid.csv`
    - `WRP_national.csv`
  - **econ/**
    - **fraser_institute/**
      - `black_market_exchange_rates.csv`
    - **maddison/**
      - (Maddison GDP file — .csv, .dta, or .xlsx)
    - **relational_export_dataset/**
      - (dyadic trade flow file — .csv or .dta)
    - **ross_oil_gas/**
      - (Ross oil & gas file — .csv or .dta)
    - **swiid/**
      - (SWIID inequality file — .csv, .dta, or .rds)
  - **fbic/**
    - (FBIC bandwidth CSV files)
  - **leader_ideology/**
    - (Global leader ideology file — .csv or .dta)
  - **mids/**
    - `FUFv1.10.csv`


---

## Source Details

### archigos/
**Archigos leaders dataset** (Goemans, Gleditsch & Chiozza).
- File: `archigos.tsv` (tab-separated)
- Unit: leader-spell (one row per leader tenure)
- Key columns: `obsid`, `ccode`, `startdate`, `enddate`
- Used by: `03_build_grave_d_ideology.R`

### atop/
**Alliance Treaty Obligations and Provisions** v5.1 (Leeds et al.).
- File: `atop5_1ddyr_NNA.csv` (directed dyad-year, non-missing alliances)
- Key columns: `statea`, `stateb`, `year` (renamed to `COWcode_a`, `COWcode_b` by pipeline)
- Used by: `04_build_controls.R`

### colgan/
**Colgan revolutionary leaders dataset** (Colgan 2012).
- Leader-level data on revolutionary leader classification.
- Used by: `03_build_grave_d_ideology.R`

### controls/cinc/
**COW National Material Capabilities** (NMC v5+).
- Key columns: `ccode`, `year`, `cinc`, `milex`, `milper`
- Used by: `04_build_controls.R`

### cow/
**Correlates of War** dyadic MID and World Religion Project data.
- `dyadic_mid.csv` — directed dyadic MID data
  - Used by: `02_build_conflict.R`
- `WRP_national.csv` — COW World Religion Project (national, 5-year intervals)
  - Key columns: `state` (COW code), `year`, `chrstgenpct`, `islmgenpct`, etc.
  - Used by: `04_build_controls.R`

### econ/
Economic control variable datasets, each in its own subdirectory:

- **fraser_institute/** — `black_market_exchange_rates.csv`
  - Fraser Institute black market premium data.
- **maddison/** — Maddison Project GDP data (.csv, .dta, or .xlsx)
- **relational_export_dataset/** — Dyadic trade flow data (.csv or .dta)
- **ross_oil_gas/** — Ross oil and gas dataset (.csv or .dta)
- **swiid/** — Standardized World Income Inequality Database (.csv, .dta, or .rds)

All used by: `04_build_controls.R`

### fbic/
**FBIC bandwidth data** (Kadera & Sorokin).
- CSV files containing directed dyadic bandwidth measures.
- Key columns: `ccode1`, `ccode2`, `year`, `bandwidth`,
  `economicbandwidth`, `politicalbandwidth`, `securitybandwidth`, `socialbandwidth`
- Used by: `01_build_fbic_spine.R`

### leader_ideology/
**Global leader ideology dataset**.
- Leader-level ideology classification data.
- Used by: `03_build_grave_d_ideology.R`

### mids/
**First Use of Violent Force (FUVF)** dataset (Caprioli & Trumbore).
- File: `FUFv1.10.csv`
- Source: http://www.d.umn.edu/~mcapriol/
- Unit: country-year (initiator-level observations)
- Key columns: `ccode` (renamed to `COWcode`), `fufyear` (renamed to `year`),
  `fuf` (1 = first user of violent force), `endate`, `fufjoin`, `midjoin`
- Pipeline creates `fuf_initiator` (binary) and merges onto Side A.
- Used by: `04_build_controls.R`

---

## V-Dem (no subdirectory needed)

V-Dem data is accessed via the **`vdemdata` R package** — no flat file required.
Install with:
\```r
remotes::install_github("vdemdata/vdemdata")

Notes
The pipeline auto-detects file formats (.csv, .dta, .xlsx, .rds, .tsv)
in most directories via list.files() with pattern matching.

All datasets are lowercased via rename_with(tolower) on load.
Country code columns (ccode, cowcode, state) are standardised
to COWcode for merging.

If a source file is missing, the pipeline logs a warning and skips
that data source — it will not error out.
