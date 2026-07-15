# AS-C.Origami

AS-C.Origami training, allele-specific prediction, SNP-density selection, and benchmark code archived from the GM12878 workflow.

## Contents

| Stage | Files | Purpose |
|---|---|---|
| Training | `training/` | Standard C.Origami and ATAC-only training launchers |
| SNP density | `snp-density/` | Build and summarize SNP-density windows used for region selection |
| Prediction | `prediction/` | Plan A, Plan E, and Plan H Snakemake prediction workflows |
| Benchmark | `benchmarks/` | Dip3D Plan A merge and combined Plan A/E/H evaluations |

See [`docs/workflow.md`](docs/workflow.md) for the stage relationships and [`docs/dependencies.md`](docs/dependencies.md) for software, data, and path requirements. [`docs/source-manifest.tsv`](docs/source-manifest.tsv) records the original location and SHA-256 of every archived source.

## Archive policy

The eight workflow files are preserved byte-for-byte, including notebook outputs and cluster-specific absolute paths. Models, genomic data, predictions, intermediate results, and helper scripts outside the requested scope are not included. Review `docs/dependencies.md` before running anything in another environment.
