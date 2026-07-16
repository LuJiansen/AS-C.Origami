# Dependencies and environment

Exact package versions were not captured by the source workflows. Recreate and
validate an environment appropriate for the installed C.Origami version before
running full jobs.

## Recommended Plan A workflow

Follow the upstream [C.Origami setup instructions](https://github.com/tanjimin/C.Origami)
to create the `corigami` environment. Standard Plan A training and prediction
require:

- C.Origami command-line programs, including `corigami-train` and
  `corigami-predict`;
- Python with PyTorch and the modules required by the installed C.Origami
  version;
- Snakemake;
- a CUDA-capable GPU environment;
- the Zenodo C.Origami GM12878 bulk data extracted at
  `src/data/corigami_data/data/`; and
- the repository's standard checkpoint, GM12878 dscNanoATAC BigWigs, ranked
  SNP-density regions, and chromosome-length file.

The launchers retain their original SLURM resource directives and the conda
environment name `corigami`. Workflow data, code, model, and output paths are
repository-local.

## SNP-density notebook

The SNP-density notebook requires R/Bioconductor packages imported by its code,
including genomic interval and tidy-data tooling. It reads the uploaded phased
VCF/index and `src/data/reference/GRCh38.chrom.sizes`. Historical output is
retained, and the resulting ranked region table is already included.

## Plan A evaluation

The Plan A benchmark notebook requires R with IRkernel, its imported R packages,
and Python packages loaded through `reticulate`. It additionally depends on
Plan A prediction `.npy` trees and external paternal, maternal, and merged Dip3D
contact matrices. Historical notebook outputs are retained, but the external
reference data is not committed.

## Benchmark-only dependencies

Plan E (All-hap.) and Plan H (No-CTCF) are experimental benchmark-only workflows
and are not part of the recommended user path. Their purpose, input mappings,
and interpretation caveats are documented in
[`../benchmarks/README.md`](../benchmarks/README.md).

Reproducing the archived Plan E input preparation requires:

- `bcftools` 1.10 or newer, `samtools`, `bgzip`, and `tabix` for the diploid
  FASTA generator;
- the downloaded hg38 reference FASTA and uploaded phased VCF/index; and
- Python packages `numpy`, `pyBigWig`, and `pysam`, the retained
  `MA0139.1.meme` motif, the downloaded bulk GM12878 CTCF BigWig, and chromosome
  lengths for allele-specific CTCF generation.

Reproducing Plan H requires the archived ATAC-only Python entry points and
checkpoint with their imported PyTorch/C.Origami modules. The combined Plan
A/E/H notebook additionally requires all plan-specific prediction trees, hg38
blacklist intervals, external Dip3D matrices, and the notebook-specific
comparison/reference matrices used by SCC and insulation calculations.

## Storage and version control

Git LFS is required to clone the two checkpoints, three GM12878 dscNanoATAC
BigWigs, and phased VCF/index. Downloaded Zenodo data, generated haplotype inputs,
training outputs, prediction matrices, external benchmark data, and notebook
runtime caches are excluded from Git.
