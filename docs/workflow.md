# Workflow

## 1. Training

`corigami_train.sh` launches standard C.Origami training with DNA sequence, CTCF, and ATAC features. `corigami_train_atac_only.sh` launches the local ATAC-only training program and records the cluster environment and resource settings used for that model.

## 2. SNP-density window selection

`SNP_density.ipynb` prepares GM12878 SNP-density summaries across genomic windows. The prediction workflows read the resulting ranked region list and limit execution with `TOP_N`.

## 3. Allele-specific prediction

- Plan A (`run_top_pred.smk`) uses the standard model to generate paternal, maternal, merged, and bulk predictions.
- Plan E (`run_top_pred_planE.smk`) uses haplotype DNA, allele-specific ATAC, and continuous PWM-weighted CTCF tracks for paternal and maternal predictions.
- Plan H (`run_top_pred_planH.smk`) uses the ATAC-only model with haplotype DNA and allele-specific ATAC, plus merged and bulk references.

Each workflow filters windows that do not fit within chromosome bounds and writes C.Origami prediction matrices by chromosome and start coordinate.

## 4. Benchmarking

`corigami_predict_benchmark_dip3d_planA_merge.ipynb` evaluates Plan A paternal, maternal, bulk, and merged predictions against matching Dip3D references using insulation correlation and SCC.

`corigami_predict_benchmark_planAEH.ipynb` compares Plans A, E, and H on shared valid windows, reports contact-map examples, SCC and insulation metrics, and retains the existing result tables and plots. Plan E bulk and merge entries are documented in the notebook as aliases of Plan A.

## Data flow

```text
reference genome + GM12878 tracks -> training -> model checkpoints
GM12878 variants -> SNP density -> ranked genomic windows
model + tracks + ranked windows -> Plan A/E/H predictions
predictions + Dip3D matrices -> benchmark notebooks -> tables and figures
```

The archive documents this flow but does not bundle the large inputs or outputs needed to reproduce it.
