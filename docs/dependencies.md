# Dependencies and environment

Exact package versions were not captured by the source workflows. Recreate and
validate an environment appropriate for the installed C.Origami version before
running full jobs.

## Training and prediction

- C.Origami command-line programs, including `corigami-train` and
  `corigami-predict`
- Python with PyTorch and the modules imported by
  `src/training/train_atac_only.py` and `src/prediction/predict_atac_only.py`
- Snakemake
- A CUDA-capable GPU environment; the launchers retain the original SLURM
  resource directives and conda environment name `corigami`
- The Zenodo C.Origami GM12878 bulk data extracted at
  `src/data/corigami_data/data/`

The ATAC-only training launcher expects `conda` on `PATH`, initializes the bash
shell hook, and activates `corigami`. Set `CORIGAMI_ENV` to use a different
environment name. Workflow data, code, model, and output paths are
repository-local.

## Diploid FASTA generation

`src/generation/diploid-dna/01_build_haplotype_fasta.sh` requires:

- `bcftools` 1.10 or newer
- `samtools`
- `bgzip` and `tabix`
- The downloaded hg38 reference FASTA and the uploaded phased VCF/index

The script generates per-chromosome paternal and maternal bgzip FASTA files and
a temporary SNP-only VCF. These generated files are excluded from Git.

## Plan E CTCF generation

`src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py` requires Python packages
`numpy`, `pyBigWig`, and `pysam`, together with:

- `src/generation/plan-e-ctcf/MA0139.1.meme`
- The uploaded phased VCF
- The downloaded hg38 reference FASTA and bulk GM12878 CTCF BigWig
- `src/data/reference/GRCh38.chrom.sizes`

## SNP-density and benchmark notebooks

The SNP-density notebook requires R/Bioconductor packages used in its code,
including genomic interval and tidy-data tooling. The benchmark notebooks require
R with IRkernel, their imported R packages, and Python packages loaded through
`reticulate`. Historical outputs are retained, but the notebooks were not fully
re-executed during repository assembly.

The benchmark analyses also depend on external data that is not committed:

- Dip3D paternal and maternal reference contact matrices
- Genomic blacklist intervals
- Ground-truth and comparison reference matrices used by SCC and insulation
  calculations
- Full prediction `.npy` output trees produced by Plans A, E, and H

## Storage and version control

Git LFS is required to clone the two checkpoints, three GM12878 dscNanoATAC
BigWigs, and phased VCF/index. Downloaded Zenodo data, generated allele-specific
inputs, training outputs, prediction matrices, and notebook runtime caches are
excluded from Git.
