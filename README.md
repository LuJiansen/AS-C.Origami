# AS-C.Origami

AS-C.Origami collects the GM12878 C.Origami training, allele-specific prediction,
SNP-density selection, input-generation, and benchmark workflows. Historical
notebook outputs are retained for reference.

## Overview

AS-C.Origami is a workflow for allele-specific chromatin conformation
prediction. It applies paternal and maternal ATAC signals obtained with
dscNanoATAC to [C.Origami](https://github.com/tanjimin/C.Origami), enabling the
model to generate allele-specific chromatin contact maps.

![AS-C.Origami workflow](docs/images/AS-COrigami_workflow.png)

## Prediction plans

AS-C.Origami provides three prediction strategies that differ in which inputs
are haplotype-specific:

![Plan A, E, and H input comparison](docs/images/plans_benchmark_workflow.png)

| Plan | Alias | DNA | ATAC | CTCF | Model |
|---|---|---|---|---|---|
| **Plan A** | **Default** | Bulk | Allele-specific | Bulk | Standard C.Origami |
| Plan E | All-hap. | Haplotype-specific | Allele-specific | Allele-specific | Standard C.Origami |
| Plan H | No-CTCF | Haplotype-specific | Allele-specific | Not used | ATAC-only C.Origami |

- **Plan A (Default)** is the recommended starting workflow. It uses the
  standard C.Origami model with bulk DNA and CTCF tracks while introducing
  paternal or maternal dscNanoATAC as the allele-specific input.
- **Plan E (All-hap.)** uses haplotype-specific DNA, dscNanoATAC, and generated
  allele-specific CTCF tracks with the standard C.Origami model.
- **Plan H (No-CTCF)** uses the ATAC-only model with haplotype-specific DNA and
  dscNanoATAC, without a CTCF input.

## Repository layout

| Path | Contents |
|---|---|
| `src/training/` | Standard C.Origami and ATAC-only training entry points |
| `src/prediction/` | Plan A, Plan E, and Plan H Snakemake workflows |
| `src/generation/` | Diploid DNA and Plan E allele-specific CTCF generators |
| `src/models/` | Standard and ATAC-only checkpoints tracked with Git LFS |
| `src/data/` | Uploaded inputs plus the location for downloaded/generated inputs |
| `snp-density/` | SNP-density notebook and retained output |
| `benchmarks/` | Plan A and combined Plan A/E/H benchmark notebooks |
| `outputs/` | Generated training and prediction results; excluded from Git |

See [`docs/workflow.md`](docs/workflow.md) for the data flow,
[`docs/dependencies.md`](docs/dependencies.md) for runtime requirements, and
[`docs/source-manifest.tsv`](docs/source-manifest.tsv) for original paths and
SHA-256 provenance.

## Inputs already included

The following inputs are versioned in this private repository. Large binaries are
stored with Git LFS.

- Standard checkpoint: `src/models/standard/epoch=78-step=47004.ckpt`
- ATAC-only checkpoint: `src/models/atac-only/epoch=46-step=55929.ckpt`
- GM12878 dscNanoATAC paternal, maternal, and merged BigWigs:
  `src/data/dscNanoATAC/GM12878_dscNanoATAC_{paternal,maternal,merged}.bw`
- Illumina Platinum Genomes phased NA12878 VCF and tabix index:
  `src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz{,.tbi}`
- Ranked SNP-density regions:
  `src/data/regions/GM12878_2M_10k_snp_density_summary.txt`
- GRCh38 chromosome lengths: `src/data/reference/GRCh38.chrom.sizes`

The phased VCF is sourced from
[Illumina Platinum Genomes](https://github.com/Illumina/PlatinumGenomes). The
three dscNanoATAC tracks are GM12878 processing outputs; the sample identity is
kept explicitly in every filename.

## Download the C.Origami bulk data

Bulk `dna_sequence` and `gm12878` inputs are not committed. Download the public
[Zenodo archive](https://zenodo.org/record/7226561/files/corigami_data_gm12878_add_on.tar.gz?download=1)
(665,184,938 bytes; published MD5 `8a5981d9ba167bfa1a4f308c3ddff4cc`)
from the repository root and verify it before extraction:

```bash
curl -L 'https://zenodo.org/record/7226561/files/corigami_data_gm12878_add_on.tar.gz?download=1' \
  -o corigami_data_gm12878_add_on.tar.gz
echo '8a5981d9ba167bfa1a4f308c3ddff4cc  corigami_data_gm12878_add_on.tar.gz' | md5sum -c -
mkdir -p src/data/corigami_data
tar -xzf corigami_data_gm12878_add_on.tar.gz -C src/data/corigami_data
test -d src/data/corigami_data/data/hg38/dna_sequence
test -d src/data/corigami_data/data/hg38/gm12878
```

The extracted `src/data/corigami_data/data/` tree is excluded from Git.

## Generate allele-specific inputs

After extracting the Zenodo data, generate the diploid DNA and Plan E paternal
and maternal CTCF BigWigs with repository-local defaults:

```bash
bash src/generation/diploid-dna/01_build_haplotype_fasta.sh
python src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py
```

These commands use the uploaded phased VCF. Generated diploid FASTA, SNP-only
VCF, and Plan E CTCF BigWigs remain under `src/data/corigami_data/data/` and are
intentionally not committed. See [`src/generation/README.md`](src/generation/README.md)
for output paths.

## Run training and prediction

Training launchers write to `outputs/training/standard/` and
`outputs/training/atac-only/`:

```bash
sbatch src/training/corigami_train.sh
sbatch src/training/corigami_train_atac_only.sh
```

Select the number of ranked SNP-density regions with `TOP_N`:

```bash
snakemake --snakefile src/prediction/run_top_pred.smk --config TOP_N=50
snakemake --snakefile src/prediction/run_top_pred_planE.smk --config TOP_N=50
snakemake --snakefile src/prediction/run_top_pred_planH.smk --config TOP_N=50
```

Plans A, E, and H write to `outputs/prediction/plan-a/`,
`outputs/prediction/plan-e/`, and `outputs/prediction/plan-h/`, respectively.

Full training and prediction require the documented C.Origami conda environment,
GPU resources, and the omitted Zenodo bulk data. The benchmark notebooks also
require external Dip3D and reference inputs listed in `docs/dependencies.md`.
