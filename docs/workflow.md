# Plan A workflow

Plan A (Default) is the recommended AS-C.Origami workflow. It introduces
paternal or maternal GM12878 dscNanoATAC into the standard C.Origami model while
retaining bulk DNA and bulk CTCF inputs.

## 1. Region preparation

The uploaded phased GM12878 VCF at
`src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz` and the
chromosome-length file at `src/data/reference/GRCh38.chrom.sizes` are the inputs
to `snp-density/SNP_density.ipynb`. The notebook ranks approximately 2 Mb windows
by heterozygous SNP density and writes the included table
`src/data/regions/GM12878_2M_10k_snp_density_summary.txt`.

## 2. Bulk and allele-specific inputs

Download the C.Origami GM12878 Zenodo archive as described in the top-level
README. It supplies the bulk hg38 DNA and GM12878 genomic-feature tree expected
by training and prediction. The repository supplies paternal, maternal, and
merged GM12878 dscNanoATAC BigWigs under `src/data/dscNanoATAC/`.

Plan A does not require generated haplotype DNA or allele-specific CTCF. Code and
inputs for those experimental comparisons remain archived; see
[`../benchmarks/README.md`](../benchmarks/README.md) for their scope.

## 3. Standard training

`src/training/corigami_train.sh` launches standard C.Origami training with bulk
DNA, CTCF, and ATAC features. It writes results to
`outputs/training/standard/`. The selected standard checkpoint is included at
`src/models/standard/epoch=78-step=47004.ckpt`, so retraining is optional when
reproducing prediction with that checkpoint. Training does not automatically
replace the included checkpoint. Plan A continues to read the included path
unless you place a selected checkpoint there or update the Snakefile's `model`
setting.

## 4. Plan A prediction

`src/prediction/run_top_pred.smk` reads the ranked region table and chromosome
lengths, rejects windows that cannot fit the 2,097,152 bp prediction interval,
and uses `TOP_N` to limit execution. It combines bulk DNA and CTCF with paternal,
maternal, merged, or bulk ATAC and writes matrices to
`outputs/prediction/plan-a/`.

Each prediction matrix is keyed by chromosome and window start as
`<chrom>_<start>.npy` below its prediction-group directory.

## 5. Plan A evaluation

`benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb` compares Plan A
paternal, maternal, bulk, and merged predictions with their mapped Dip3D
references using SCC and insulation correlation. Its historical outputs are
retained, but reproducing the notebook requires external Dip3D and reference
matrices.

Detailed metric definitions, reference mappings, window filters, and the
separate experimental Plan A/E/H comparison are documented in
[`../benchmarks/README.md`](../benchmarks/README.md).

## Data flow

```text
Platinum Genomes phased VCF + chromosome lengths
                         |
                         v
              SNP-density notebook ----> ranked regions

Zenodo bulk DNA + GM12878 tracks ----> standard training
                                              |
                                              v
                                  outputs/training/standard/

included checkpoint at src/models/standard/epoch=78-step=47004.ckpt
                                                           |
ranked regions + bulk DNA/CTCF + GM12878 dscNanoATAC -------+
                                                           v
                                                  Plan A predictions
                                                           |
external Dip3D/reference matrices -------------------------+
                                                           v
                                                  Plan A evaluation
```
