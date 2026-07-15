# Dependencies and environment

## Software

- C.Origami command-line tools, including `corigami-train` and `corigami-predict`
- Conda environment named `corigami`
- Python/PyTorch and the local ATAC-only training and inference programs
- Snakemake and a GPU-enabled cluster execution environment
- R with IRkernel and the packages loaded by the benchmark notebooks
- Python packages loaded through `reticulate` in the benchmark notebooks

Exact package versions were not captured by the requested files and are therefore not inferred here.

## External code

- `/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/train_atac_only.py`
- `/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/predict_atac_only.py`

These programs are referenced by the archived launchers but are outside the explicitly requested archive scope.

## External data

The workflows require model checkpoints, haplotype and bulk DNA sequences, allele-specific and bulk ATAC BigWig tracks, CTCF tracks, chromosome sizes, ranked SNP-density windows, Dip3D reference matrices, blacklist intervals, and prediction `.npy` files. These are intentionally excluded because they are generated data, reference data, or large binary artifacts.

## Cluster-specific paths

The archived files retain absolute paths under `/gpfs1` and `/home/tangfuchou_pkuhpc`. They describe the environment in which the workflow was used and must be reviewed before running on another system. No path has been parameterized in this archive.

## Execution limits

Notebook outputs are retained for reference, but the notebooks were not re-executed during archiving. Snakemake dry-runs are also not part of archive verification because top-level workflow evaluation reads external files.

The archived `run_top_pred_planE.smk` currently references `seq` and `ctcf` in its `merge_pred` rule even though only haplotype-specific `seq_pat`, `seq_mat`, `ctcf_pat`, and `ctcf_mat` variables are declared. This is preserved as source provenance rather than silently corrected; review and resolve it before executing Plan E.
