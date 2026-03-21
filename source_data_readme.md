source_data/ Directory Guide
============================

This directory contains all external source datasets used by the GRAVE-D data production pipeline (`grave_d_data2026`). Each subdirectory holds one logical data source. Files here are **not** produced by the pipeline — they are inputs only.

> **Git policy:** `source_data/` is listed in `.gitignore`. You must populate these directories manually before running the pipeline scripts (`R/01_build_fbic_spine.R` through `R/06_impute_controls.R`).

Directory Layout
----------------

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
    - `capdist.csv` (Gleditsch & Ward / Weidmann capitals distance)
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
  - **nags/**
    - (Dangerous Companions / Non-State Armed Groups dyadic support data — .dta or .csv)
  - **ucdp_nonstate/**
    - (UCDP non-state conflict data used in 02b_build_nonstate_conflict.R — .dta or .csv)

Source Details
--------------

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

**Colgan revolutionary leaders dataset** (Colgan 2012/2013).

- Leader-level data on revolutionary leader classification.
- Used by: `03_build_grave_d_ideology.R`

### controls/cinc/

**COW National Material Capabilities** (NMC v5+).

- Key columns: `ccode`, `year`, `cinc`, `milex`, `milper`
- Used by: `04_build_controls.R`

### cow/

**Correlates of War** dyadic MID, World Religion Project, and contiguity-related data.

- `dyadic_mid.csv` — directed dyadic MID data  
  - Used by: `02_build_conflict.R`
- `WRP_national.csv` — COW World Religion Project (national, 5-year intervals)  
  - Key columns: `state` (COW code), `year`, `chrstgenpct`, `islmgenpct`, etc.  
  - Used by: `04_build_controls.R`
- `capdist.csv` — Gleditsch & Ward / Weidmann capitals distance  
  - Key columns: COW numeric codes for dyad members, distance in km  
  - Used by: `01_build_fbic_spine.R` or later merges for dyadic distance controls.

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

**FBIC bandwidth data** (Moyer et al.).

- CSV files containing directed dyadic bandwidth measures.
- Key columns: `ccode1`, `ccode2`, `year`, `bandwidth`, `economicbandwidth`, `politicalbandwidth`, `securitybandwidth` (socialbandwidth optional / legacy)
- Used by: `01_build_fbic_spine.R`

### leader_ideology/

**Global leader ideology dataset**.

- Leader-level ideology classification data, including left–right positions, party identifiers, and regime-level controls.
- Used by: `03_build_grave_d_ideology.R` to construct variables such as `hog_ideology`, `leader_ideology`, their numeric codings, and match indicators.

### mids/

**First Use of Violent Force (FUVF)** dataset (Caprioli & Trumbore).

- File: `FUFv1.10.csv`
- Source: http://www.d.umn.edu/~mcapriol/
- Unit: country-year (initiator-level observations)
- Key columns: `ccode` (renamed to `COWcode`), `fufyear` (renamed to `year`), `fuf` (1 = first user of violent force), `endate`, `fufjoin`, `midjoin`
- Pipeline creates `fuf_initiator` (binary) and merges onto Side A.
- Used by: `04_build_controls.R`

### nags/

**Dangerous Companions / Non-State Armed Groups (NAGs) Dataset** (San-Akca).

- Files: NAGs dyadic support data (e.g., `dangerous_companions_nags.dta` or equivalent).
- Unit: state–rebel group–year (triadic), transformed to dyad-year and triadic indicators in the pipeline.
- Key content: external state support to rebel groups, support type (arms, funds, troops, training, safe haven), and NAGs objective and ideology codes.
- Used by: `03c_build_nags.R` and `03d_merge_triadic_nags.R` to produce variables including:
  - `nags_nondem_objective`
  - `nags_auth_support`
  - `nags_ethnonationalist`
  - `nags_religious`
  - `nags_leftist`
  - `nags_obj_topple`
  - `nags_obj_regimechange`
  - `nags_obj_autonomy`
  - `nags_obj_secession`
  - `nags_obj_policy`
  - `nags_obj_other`

### ucdp_nonstate/

**UCDP non-state conflict datasets** (battle-related deaths, non-state conflicts, etc.).

- Files: UCDP non-state conflict data needed to construct monadic non-state conflict controls (e.g., `.dta` or `.csv` files from UCDP).
- Unit: conflict–year or dyad–year depending on specific UCDP product.
- Used by: `02b_build_nonstate_conflict.R` to create `nonstate_conflict_a`, `nonstate_conflict_b`, and related monadic controls.

V-Dem (no subdirectory needed)
------------------------------

V-Dem data is accessed via the **`vdemdata` R package** — no flat file required. Install with:

```r
remotes::install_github("vdemdata/vdemdata")
