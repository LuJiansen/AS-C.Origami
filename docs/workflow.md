# Workflow

## 1. Shared data preparation

The uploaded phased GM12878 VCF at
`src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz`
is the shared variant source for two branches:

- `snp-density/SNP_density.ipynb` ranks 2 Mb windows by heterozygous SNP density
  and writes `src/data/regions/GM12878_2M_10k_snp_density_summary.txt`.
- `src/generation/diploid-dna/01_build_haplotype_fasta.sh` filters biallelic SNPs
  and creates paternal and maternal FASTA trees under the downloaded C.Origami
  data root.

The bulk reference DNA, GM12878 ATAC, and GM12878 CTCF inputs must be downloaded
from the Zenodo archive described in the repository README. Plan E additionally
uses `src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py` to combine phased
variants, the bulk CTCF track, and `MA0139.1.meme` into paternal and maternal
continuous PWM-modulated CTCF BigWigs.

## 2. Training

`src/training/corigami_train.sh` launches standard C.Origami training with bulk
DNA, CTCF, and ATAC features. `src/training/corigami_train_atac_only.sh` launches
`src/training/train_atac_only.py` for the ATAC-only model. Outputs are written to
`outputs/training/standard/` and `outputs/training/atac-only/`.

The repository includes the selected standard and ATAC-only checkpoints in
`src/models/standard/` and `src/models/atac-only/`.

## 3. Allele-specific prediction

All three Snakefiles read the shared region table and chromosome-length file,
filter windows that cannot fit a 2,097,152 bp prediction interval, and use
`TOP_N` to limit execution.

- Plan A, `src/prediction/run_top_pred.smk`, uses bulk DNA and bulk CTCF with
  paternal, maternal, merged, or bulk ATAC. It writes to
  `outputs/prediction/plan-a/`.
- Plan E, `src/prediction/run_top_pred_planE.smk`, uses haplotype DNA,
  GM12878 dscNanoATAC, and generated allele-specific continuous-PWM CTCF for the
  paternal and maternal predictions. The merged and bulk predictions use bulk
  DNA and bulk CTCF. It writes to `outputs/prediction/plan-e/`.
- Plan H, `src/prediction/run_top_pred_planH.smk`, calls
  `src/prediction/predict_atac_only.py` with haplotype DNA and paternal/maternal
  GM12878 dscNanoATAC, plus merged and bulk references. It writes to
  `outputs/prediction/plan-h/`.

Each prediction matrix is keyed by chromosome and window start as
`<chrom>_<start>.npy` below the plan-specific output root.

## 4. Benchmarking

`benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb` evaluates Plan A
paternal, maternal, bulk, and merged predictions against matching Dip3D matrices
using insulation correlation and SCC.

`benchmarks/corigami_predict_benchmark_planAEH.ipynb` compares Plans A, E, and H
on shared valid windows. It retains historical result tables and plots. Plan E
bulk and merged entries are aliases of Plan A in the archived analysis.

Benchmark `.npy` references, blacklist intervals, and comparison matrices are
external inputs and are not committed.

## Data flow

```text
Platinum Genomes phased VCF ----> SNP-density notebook ----> ranked regions
              |
              +---------------> diploid DNA generator -----> paternal/maternal DNA
              |
              +-- bulk CTCF + PWM generator ---------------> Plan E pat/mat CTCF

Zenodo bulk DNA + GM12878 tracks ----> training ------------> checkpoints
checkpoints + ranked regions + tracks ----------------------> Plan A/E/H predictions
predictions + external Dip3D/reference matrices -----------> benchmark notebooks
```
