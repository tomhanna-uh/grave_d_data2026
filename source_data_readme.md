# source_data README

Each subdirectory in `source_data/` contains raw or snapshot data from a
distinct external source. Files here are treated as inputs to the
`R/00–05_*.R` scripts and should be as close to the original downloads
as possible.

## cow/

- Contents: Correlates of War (COW) data used to build the dyadic
  conflict and state system backbone (e.g., state system membership,
  dyadic MID data, and any other COW series you use).
- Used by:
  - `R/01_build_fbic_spine.R` (COW codes, system membership, dyadic structure)
  - `R/02_build_conflict.R` (dyadic MIDs / conflict measures)

## colgan/

- Contents: Jeff Colgan’s **leader-level** dataset (e.g., revolutionary
  leaders or other leader traits), stored in its original format (e.g.,
  `.dta` or `.csv`).
- Used by:
  - `R/03_build_grave_d_ideology.R` (or the first script where you merge
    Colgan leader data onto Archigos / GRAVE-D leaders)

## atop/

- Contents: Alliance Treaty Obligations and Provisions (ATOP) data used
  for alliance-related variables in the dyadic GRAVE-D dataset (e.g.,
  dyad-year or directed-dyad-year alliance data).
- Used by:
  - `R/04_build_controls.R` (or whichever script constructs alliance
    control variables for the dyadic dataset)

## fbic/

- Contents: Formal Bilateral Influence Capacity (FBIC) data, including
  dyadic influence scores and any accompanying codebook snapshot.
- Used by:
  - `R/01_build_fbic_spine.R` (to attach FBIC-based dyadic structure and
    influence measures to the spine)
  - Optionally `R/04_build_controls.R` if you construct additional
    FBIC-based controls

## econ/

- Contents: Country-year economic and resource covariates (e.g., Ross
  oil and gas data, GDP, trade, or other macroeconomic indicators).
- Used by:
  - `R/04_build_controls.R` (economic and resource controls)

## archigos/

- Contents: Archigos leader data files (original or minimally cleaned),
  including leader identity, tenure dates, and basic attributes.
- Used by:
  - `R/03_build_grave_d_ideology.R` (building leader-level components of
    GRAVE-D and merging leader attributes)

## leader_ideology/

- Contents: Global leader ideology dataset files used to code leaders’
  ideological positions or support bases.
- Used by:
  - `R/03_build_grave_d_ideology.R` (merging ideology onto leaders and
    into the dyadic GRAVE-D structure)

## vdem/ (optional)

- Contents: Only used if you intentionally store **local V-Dem snapshots**
  (CSV/RDS) instead of loading V-Dem via the R package. If you rely on
  the V-Dem package (as in the original setup), this directory should be
  empty or absent, and all V-Dem access should occur inside scripts via
  the package.
- Used by:
  - If present: whichever script explicitly reads V-Dem files
    (typically `R/04_build_controls.R` for regime and democracy measures)
  - If absent: V-Dem variables are obtained via the R package only, not
    from `source_data/`


| Directory                                   | Unit of analysis           | Main variables / content                                          | Used in scripts                         |
|--------------------------------------------|----------------------------|-------------------------------------------------------------------|-----------------------------------------|
| cow/                                       | state-year, dyad-year      | State system membership, dyadic MIDs (`dyadic_mid.csv`), WRP_national (world religions) | 01_build_fbic_spine.R, 02_build_conflict.R |
| cow/dyadic_mid.csv                         | directed dyad-year         | MID onset, duration, fatalities, initiator flags, hostility level | 02_build_conflict.R                     |
| cow/WRP_national.csv                       | state-year                 | Major religion shares / categories (COW world religions project)  | 04_build_controls.R (religion controls) |
| colgan/                                    | leader, leader-year        | Colgan leader data (e.g., revolutionary leaders, leader traits)   | 03_build_grave_d_ideology.R             |
| archigos/                                  | leader, leader-year        | Archigos leader IDs, tenure dates, status, basic attributes       | 03_build_grave_d_ideology.R             |
| leader_ideology/                           | leader, leader-year        | Global leader ideology scores / categories                        | 03_build_grave_d_ideology.R             |
| atop/                                      | dyad-year or treaty-year   | Alliance membership, type, obligations (ATOP alliance data)       | 04_build_controls.R                     |
| fbic/                                      | dyad-year                  | Formal Bilateral Influence Capacity scores and related measures   | 01_build_fbic_spine.R, 04_build_controls.R |
| controls/                                  | varies (state-year, dyad)  | Higher-level grouping for capability and state-capacity controls  | 04_build_controls.R                     |
| controls/cinc/                             | state-year                 | CINC / National Material Capabilities and components              | 04_build_controls.R                     |
| controls/state_capacity/                   | state-year                 | State capacity indicators (not yet used)                          | (planned for 04_build_controls.R)       |
| econ/                                      | state-year, dyad-year      | Economic and resource covariates                                  | 04_build_controls.R                     |
| econ/fraser_institute/black_market_exchange_rates.csv | state-year     | Black market exchange rate measures (Fraser Institute)            | 04_build_controls.R                     |
| econ/maddison/                             | state-year                 | GDP, GDP per capita, and related Maddison Project data            | 04_build_controls.R                     |
| econ/relational_export_dataset/            | dyad-year                  | Relational export / trade flow data                               | 04_build_controls.R                     |
| econ/ross_oil_gas/                         | state-year                 | Oil and gas production / revenue measures (Ross)                  | 04_build_controls.R                     |
| econ/swiid/                                | state-year                 | Inequality data (e.g., Gini) from SWIID                          | 04_build_controls.R                     |
| econ/codebooks/                            | n/a                        | PDF/codebook copies for econ and related datasets                | Documentation only (not read by scripts)|
| vdem/ (optional)                           | state-year, country-year   | Only if you store local V-Dem snapshots; otherwise empty/absent   | If used: 04_build_controls.R; else package only |
