# Generated allele-specific inputs

From the repository root, after extracting the Zenodo data and installing the dependencies listed in `docs/dependencies.md`:

```bash
bash src/generation/diploid-dna/01_build_haplotype_fasta.sh
python src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py
```

The first command creates paternal and maternal FASTA directories plus a rebuildable SNP-only VCF under `src/data/corigami_data/data/hg38/dna_sequence_diploid/`. The second creates paternal and maternal continuous-PWM CTCF BigWigs under `src/data/corigami_data/data/hg38/gm12878/genomic_features/plan-e/`. These outputs are intentionally not committed.
