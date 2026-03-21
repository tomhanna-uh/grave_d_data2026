# GRAVE-D Temporal Fusion Transformer (TFT) Analysis

This directory contains experimental code and notebooks for applying a Temporal Fusion Transformer (TFT) to the GRAVE-D dyadic panel data. The primary goals are:

- To build and evaluate sequence models for conflict- and regime-related outcomes using GRAVE-D and related covariates.
- To generate out-of-sample predictions for use as counterfactuals in downstream causal inference workflows (e.g., double-robust AIPW with bootstrap-based confidence intervals).

## Contents

- `GRAVE-D_TFT_clean.ipynb`  
  Main Colab notebook for:
  - Constructing TFT-ready datasets from the GRAVE-D panel.
  - Training a TFT model with GPU acceleration and early stopping.
  - Saving trained checkpoints for later evaluation and counterfactual prediction.
  - (Planned) Evaluation of predictive performance and export of predictions for causal analysis.

Additional scripts or notebooks for model evaluation, hyperparameter tuning, and AIPW/bootstrapping will be added here as the project develops.

## Relationship to the Main GRAVE-D Repository

This analysis directory assumes that:

- Core data construction and cleaning (ETL) for GRAVE-D are handled in the main repository (e.g., `data/` or `etl/`), primarily via R and supporting Python scripts.
- Cleaned and, where applicable, multiply imputed GRAVE-D datasets are available as input to the TFT notebook (paths are configured within the notebook).

This directory **does not** contain raw GRAVE-D data. It is intended for model development, diagnostics, and generation of derived prediction outputs based on the existing data pipeline.

## Reproducibility Notes

- The notebook is designed to run on GPU-backed environments (e.g., Google Colab, UH HPC clusters with NVIDIA GPUs).
- Exact Python, PyTorch, and PyTorch Forecasting versions can affect model and prediction APIs. Users should consult the notebook header or environment files (if present) for the recommended software versions.
- Checkpoints produced here (e.g., `tft-grave-d-epoch=XX-val_loss=YY.ckpt`) are saved outside this directory (typically on mounted storage) and should be versioned or archived separately as needed.
