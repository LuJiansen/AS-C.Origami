# Benchmark Documentation Split Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Plan A (Default) the only recommended workflow in the top-level documentation and provide a self-contained benchmark guide for the archived Plan A and experimental Plan A/E/H analyses.

**Architecture:** Repository contract tests define the documentation boundary before the Markdown is changed. The top-level README and workflow guide describe the Plan A production path, while `benchmarks/README.md` owns all Plan A/E/H comparison details, metric definitions, and the comparison figure; supporting dependency documentation labels experimental tooling as benchmark-only.

**Tech Stack:** Markdown, Python `unittest`, Jupyter notebooks retained as immutable reference artifacts, Git LFS, Git.

## Global Constraints

- Keep all documentation in English.
- Present Plan A (Default) as the only recommended AS-C.Origami workflow.
- Treat Plan E (All-hap.) and Plan H (No-CTCF) as experimental benchmark-only workflows that are not recommended for users.
- Preserve all scripts, checkpoints, notebooks, notebook paths, and notebook outputs unchanged.
- Keep `benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb` as the primary Plan A evaluation notebook and mention it briefly in the top-level README.
- Keep `docs/images/AS-COrigami_workflow.png` at its current path.
- Move `docs/images/plans_benchmark_workflow.png` to `benchmarks/images/plans_benchmark_workflow.png` without changing its bytes.
- Keep downloaded Zenodo data, generated haplotype inputs, prediction outputs, and external Dip3D inputs outside Git as already documented.
- Use `$HOME/.local/bin` in `PATH` for Git LFS commands.
- Preserve unrelated worktree changes if any appear during implementation.

---

## File Structure

- Create `benchmarks/README.md`: canonical benchmark scope, plan comparison, notebook roles, region selection, reference mapping, metric definitions, caveats, dependencies, and outputs.
- Create `benchmarks/images/plans_benchmark_workflow.png`: byte-identical moved Plan A/E/H comparison figure.
- Delete `docs/images/plans_benchmark_workflow.png`: obsolete location after the Git move.
- Modify `README.md`: Plan A-only user workflow, standard training, Plan A prediction, concise Plan A evaluation, and link to benchmark documentation.
- Modify `docs/workflow.md`: Plan A production data flow only, with experimental comparisons delegated to the benchmark README.
- Modify `docs/dependencies.md`: separate production dependencies from benchmark-only Plan E/H and notebook dependencies.
- Modify `tests/test_repository_contract.py`: enforce the benchmark entry point, top-level Plan A boundary, supporting-document boundary, image move, and unchanged notebook outputs.

### Task 1: Add the benchmark documentation entry point

**Files:**
- Create: `benchmarks/README.md`
- Create: `benchmarks/images/plans_benchmark_workflow.png`
- Delete: `docs/images/plans_benchmark_workflow.png`
- Modify: `tests/test_repository_contract.py`
- Preserve: `benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb`
- Preserve: `benchmarks/corigami_predict_benchmark_planAEH.ipynb`

**Interfaces:**
- Consumes: the two existing benchmark notebooks, the existing figure at `docs/images/plans_benchmark_workflow.png`, and paths documented in `src/prediction/`.
- Produces: `benchmarks/README.md` as the canonical link target used by the top-level and supporting documentation in later tasks.

- [ ] **Step 1: Add the failing benchmark documentation contract**

Append this method to `RepositoryContractTest` in `tests/test_repository_contract.py`:

```python
    def test_benchmark_documentation_is_self_contained(self):
        readme_path = ROOT / "benchmarks/README.md"
        image_path = ROOT / "benchmarks/images/plans_benchmark_workflow.png"
        old_image_path = ROOT / "docs/images/plans_benchmark_workflow.png"

        self.assertTrue(readme_path.is_file())
        self.assertTrue(image_path.is_file())
        self.assertFalse(old_image_path.exists())

        text = readme_path.read_text()
        required = (
            "Default",
            "All-hap.",
            "No-CTCF",
            "experimental benchmark-only",
            "corigami_predict_benchmark_dip3d_planA_merge.ipynb",
            "corigami_predict_benchmark_planAEH.ipynb",
            "Stratified Correlation Coefficient (SCC)",
            "Insulation correlation",
            "Paternal-maternal SCC concordance",
            "Matched and mismatched haplotype SCC",
            "SCC versus merged Dip3D",
            "SNP-density association",
            "Plan E `all` and `merge` entries are aliases of Plan A",
            "images/plans_benchmark_workflow.png",
        )
        for phrase in required:
            self.assertIn(phrase, text)
```

- [ ] **Step 2: Run the focused test and verify that it fails for the missing benchmark entry point**

Run:

```bash
python -m unittest -v \
  tests.test_repository_contract.RepositoryContractTest.test_benchmark_documentation_is_self_contained
```

Expected: `FAIL`; the first failure reports that `benchmarks/README.md` is not a file.

- [ ] **Step 3: Move the comparison image without changing its contents**

Run:

```bash
mkdir -p benchmarks/images
git mv docs/images/plans_benchmark_workflow.png \
  benchmarks/images/plans_benchmark_workflow.png
sha256sum benchmarks/images/plans_benchmark_workflow.png
```

Expected SHA-256:

```text
5b415f8aba20b37b144f780e3fe2159d18ef00c1333f39e885ed2573f3ebab61  benchmarks/images/plans_benchmark_workflow.png
```

- [ ] **Step 4: Create the complete benchmark README**

Create `benchmarks/README.md` with this content:

````markdown
# AS-C.Origami benchmarks

This directory contains the retained evaluation notebooks for AS-C.Origami.
Plan A (Default) is the recommended user workflow. Plan E (All-hap.) and Plan H
(No-CTCF) are experimental benchmark-only workflows retained to test alternative
input combinations; they are not recommended production workflows.

Notebook outputs are preserved as historical reference results. Reproducing the
analyses requires prediction trees and external Dip3D/reference data that are
not stored in this repository.

## Prediction plans

![Plan A, E, and H input comparison](images/plans_benchmark_workflow.png)

| Plan | Alias | DNA | ATAC | CTCF | Model | Intended use |
|---|---|---|---|---|---|---|
| **Plan A** | **Default** | Bulk | Allele-specific | Bulk | Standard C.Origami | Recommended AS-C.Origami workflow |
| Plan E | All-hap. | Haplotype-specific | Allele-specific | Allele-specific | Standard C.Origami | Experimental benchmark only |
| Plan H | No-CTCF | Haplotype-specific | Allele-specific | Not used | ATAC-only C.Origami | Experimental benchmark only |

Plan A isolates the effect of paternal or maternal GM12878 dscNanoATAC while
retaining the standard C.Origami DNA, CTCF, and model inputs. Plan E tests
haplotype-specific DNA and generated allele-specific CTCF together with the
allele-specific ATAC signal. Plan H removes CTCF and uses the archived ATAC-only
model with haplotype-specific DNA and ATAC.

The prediction workflows are retained at
`../src/prediction/run_top_pred.smk`,
`../src/prediction/run_top_pred_planE.smk`, and
`../src/prediction/run_top_pred_planH.smk`. Plan E/H commands are intentionally
omitted from the primary user workflow because these plans exist only for the
archived comparison.

## Notebooks

### Primary Plan A evaluation

[`corigami_predict_benchmark_dip3d_planA_merge.ipynb`](corigami_predict_benchmark_dip3d_planA_merge.ipynb)
evaluates the four Plan A prediction groups: paternal (`pat`), maternal (`mat`),
bulk (`all`), and merged dscNanoATAC (`merge`). Paternal and maternal predictions
are compared with their matching Dip3D haplotypes; `all` and `merge` are compared
with the merged Dip3D reference.

The notebook takes the intersection of regions available in all four Plan A
prediction directories and joins those windows to the ranked SNP-density table.
It evaluates 10 kb matrices over 210 bins (approximately 2.1 Mb), resizing the
native prediction output to 210 x 210 when required. Results are summarized over
all available regions and the top 100 SNP-dense regions.

### Experimental Plan A/E/H comparison

[`corigami_predict_benchmark_planAEH.ipynb`](corigami_predict_benchmark_planAEH.ipynb)
compares Plan A with the experimental Plan E and Plan H workflows. It uses 10 kb,
210-bin windows and selects up to 5,000 regions that:

- occur across every plan and prediction type used by the comparison;
- pass chromosome-bound and Dip3D start-bin availability checks;
- are ordered by the ranked SNP-density table; and
- overlap the hg38 blacklist by no more than 50 kb.

The prediction types are `pat`, `mat`, `all`, and `merge`. Paternal and maternal
predictions map to paternal and maternal Dip3D references, respectively; `all`
and `merge` map to the merged Dip3D reference.

Important alias caveat: Plan E `all` and `merge` entries are aliases of Plan A
rather than independent Plan E predictions. They must not be interpreted as
independent evidence for Plan E.

## Metrics

### Stratified Correlation Coefficient (SCC)

SCC is a HiCRep-style similarity score between two contact matrices. Contacts
are stratified by genomic separation, a correlation is calculated within each
usable distance stratum, and the stratum correlations are combined using
variance- and sample-size-derived weights. SCC is nominally in the interval
[-1, 1]; a higher value indicates more similar distance-aware contact structure.

Both notebooks use 10 kb resolution. The Plan A/E/H notebook calls
`hicrep::get.scc` with smoothing `h = 1` and a 0-1 Mb distance range. The Plan A
notebook applies smoothing equivalent to `h = 5`, uses its caller's 0-1 Mb
default range, masks bins with SNP counts less than or equal to 1, and retries
invalid comparisons through its fallback calculation. Group summaries report
the number of valid observations together with mean and median SCC.

### Insulation correlation

Each matrix is converted to an insulation-like one-dimensional track by
aggregating contacts across a local diagonal window. Both notebooks use a
20-bin diagonal window. After the notebook-specific smoothing and normalization,
predicted and reference tracks are compared using pairwise-complete Pearson
correlation. A higher value means that the predicted map more closely reproduces
the reference's boundary and insulation variation.

In the Plan A notebook, paternal and maternal reference matrices use smoothing
`h = 5`, while merged-reference comparisons for `all` and `merge` use `h = 1`.
Bins require a SNP count of at least 1. The Plan A/E/H notebook uses reference
smoothing `h = 5` for this metric. Missing or invalid bins reduce the number of
paired observations and therefore may change the reported sample size.

### Paternal-maternal SCC concordance

For each window, the Plan A/E/H notebook first calculates SCC between paternal
and maternal Dip3D maps and separately calculates SCC between paternal and
maternal predicted maps. It then uses Pearson correlation across windows to
measure whether predicted paternal-maternal similarity tracks the corresponding
Dip3D similarity. This across-window Pearson statistic is distinct from the
per-window SCC values used to construct it.

### Matched and mismatched haplotype SCC

Paternal and maternal predictions are each compared with both paternal and
maternal Dip3D references. A comparison is marked matched when prediction and
reference haplotypes agree (`pat` with `pat`, or `mat` with `mat`) and mismatched
for the cross-haplotype pairs. The resulting SCC distributions test whether the
predictions preferentially resemble their corresponding haplotype.

### SCC versus merged Dip3D

The `all` and `merge` prediction matrices are compared with the merged Dip3D
reference using SCC. In the Plan A/E/H notebook, remember that Plan E `all` and
`merge` are Plan A aliases, so those rows do not represent separately generated
Plan E matrices.

### SNP-density association

The Plan A notebook relates each window's mean SNP density to its insulation
correlation and reports summaries for all regions and the top 100 SNP-dense
regions. Its displayed Pearson association summary further filters windows to
mean SNP-density values between 30 and 50. This filtered result should be read
as the notebook's selected-window analysis, not as an unfiltered genome-wide
association.

## Aggregation and interpretation

Metric tables report the available observation count (`n`) and mean/median
values for applicable plan and prediction groups. The notebooks also retain
scatter or density plots, boxplots, violin plots, contact-map examples, and
locus-level spot checks. Filtering, missing inputs, invalid correlations, and
the shared-window intersection can produce different `n` values among metrics;
compare plans using both the reported statistic and its observation count.

These analyses evaluate agreement with the available Dip3D matrices on selected
SNP-dense windows. They do not establish that the experimental Plan E or Plan H
input combinations are preferable to the recommended Plan A workflow.

## Required external inputs and outputs

The notebooks expect the relevant trees under `../outputs/prediction/`, plus
external Dip3D paternal, maternal, and merged matrices, hg38 blacklist intervals,
and notebook-specific comparison/reference matrices. These external benchmark
inputs and generated result tables are not committed. See
[`../docs/dependencies.md`](../docs/dependencies.md) for software and data
requirements and [`../docs/workflow.md`](../docs/workflow.md) for the recommended
Plan A production data flow.
````

- [ ] **Step 5: Run the focused test and verify that it passes**

Run:

```bash
python -m unittest -v \
  tests.test_repository_contract.RepositoryContractTest.test_benchmark_documentation_is_self_contained
```

Expected: `OK` with one passing test.

- [ ] **Step 6: Verify that notebook outputs and the moved image are unchanged**

Run:

```bash
python -m unittest -v \
  tests.test_repository_contract.RepositoryContractTest.test_notebook_outputs_are_unchanged
printf '%s  %s\n' \
  '5b415f8aba20b37b144f780e3fe2159d18ef00c1333f39e885ed2573f3ebab61' \
  'benchmarks/images/plans_benchmark_workflow.png' | sha256sum -c -
```

Expected: the notebook-output test reports `OK`; `sha256sum` reports
`benchmarks/images/plans_benchmark_workflow.png: OK`.

- [ ] **Step 7: Commit the benchmark entry point**

Run:

```bash
git add tests/test_repository_contract.py benchmarks/README.md \
  benchmarks/images/plans_benchmark_workflow.png \
  docs/images/plans_benchmark_workflow.png
git commit -m "docs: add benchmark methodology guide"
```

Expected: one commit containing the new guide, contract test, and image rename.

### Task 2: Make the top-level README Plan A-only

**Files:**
- Modify: `README.md`
- Modify: `tests/test_repository_contract.py`

**Interfaces:**
- Consumes: the canonical benchmark guide created in Task 1 and the existing Plan A workflow at `src/prediction/run_top_pred.smk`.
- Produces: a user-facing entry point that contains only standard training, Plan A prediction, and primary Plan A evaluation commands.

- [ ] **Step 1: Add the failing top-level documentation boundary contract**

Append this method to `RepositoryContractTest`:

```python
    def test_top_level_readme_documents_only_plan_a_workflow(self):
        text = (ROOT / "README.md").read_text()

        required = (
            "Plan A (Default)",
            "src/training/corigami_train.sh",
            "src/prediction/run_top_pred.smk",
            "benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb",
            "benchmarks/README.md",
            "SCC",
            "insulation correlation",
        )
        forbidden = (
            "corigami_train_atac_only.sh",
            "run_top_pred_planE.smk",
            "run_top_pred_planH.smk",
            "plans_benchmark_workflow.png",
        )
        for phrase in required:
            self.assertIn(phrase, text)
        for phrase in forbidden:
            self.assertNotIn(phrase, text)
```

- [ ] **Step 2: Run the focused test and verify that the current README fails**

Run:

```bash
python -m unittest -v \
  tests.test_repository_contract.RepositoryContractTest.test_top_level_readme_documents_only_plan_a_workflow
```

Expected: `FAIL` because the current README still names the ATAC-only launcher,
Plan E/H Snakefiles, and comparison image.

- [ ] **Step 3: Rewrite the README around the recommended Plan A workflow**

Replace `README.md` with this content:

````markdown
# AS-C.Origami

AS-C.Origami applies paternal and maternal ATAC signals obtained from GM12878
dscNanoATAC to [C.Origami](https://github.com/tanjimin/C.Origami), enabling
allele-specific chromatin conformation prediction. Plan A (Default) is the
recommended workflow: it uses bulk DNA and CTCF inputs with paternal or maternal
dscNanoATAC and the standard C.Origami model.

Historical notebook outputs are retained for reference.

## Recommended workflow

![AS-C.Origami workflow](docs/images/AS-COrigami_workflow.png)

The production path uses the uploaded phased VCF and chromosome lengths to rank
SNP-dense windows, the public C.Origami GM12878 data for bulk DNA and genomic
features, and the included allele-specific dscNanoATAC BigWigs. Standard
C.Origami training produces or replaces the included standard checkpoint, and
Plan A predicts paternal, maternal, bulk, and merged contact maps on the selected
windows.

Plan A is the only recommended user workflow. Experimental input combinations
and their archived comparisons are documented separately in
[`benchmarks/README.md`](benchmarks/README.md).

## Repository layout

| Path | Contents |
|---|---|
| `src/training/` | Standard C.Origami training entry point and archived benchmark-only training code |
| `src/prediction/` | Recommended Plan A workflow and archived benchmark-only prediction workflows |
| `src/generation/` | Code retained to generate experimental haplotype inputs |
| `src/models/` | Model checkpoints tracked with Git LFS |
| `src/data/` | Uploaded inputs plus the location for downloaded/generated inputs |
| `snp-density/` | SNP-density notebook and retained output |
| `benchmarks/` | Primary Plan A evaluation and archived experimental comparison |
| `outputs/` | Generated training and prediction results; excluded from Git |

See [`docs/workflow.md`](docs/workflow.md) for the Plan A data flow,
[`docs/dependencies.md`](docs/dependencies.md) for runtime requirements, and
[`docs/source-manifest.tsv`](docs/source-manifest.tsv) for original paths and
SHA-256 provenance.

## Inputs already included

The following Plan A inputs are versioned in this private repository. Large
binaries are stored with Git LFS.

- Standard checkpoint: `src/models/standard/epoch=78-step=47004.ckpt`
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

## Environment setup

Before running AS-C.Origami, follow the installation and environment setup
steps in the upstream [C.Origami repository](https://github.com/tanjimin/C.Origami)
to configure the `corigami` environment. The Plan A prediction workflow activates
an environment with that name, and the standard training launcher expects
`corigami-train` on `PATH`.

Install Snakemake and the remaining production dependencies listed in
[`docs/dependencies.md`](docs/dependencies.md).

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

## Rank SNP-dense regions

The retained `snp-density/SNP_density.ipynb` uses the uploaded phased VCF and
chromosome-length file to generate
`src/data/regions/GM12878_2M_10k_snp_density_summary.txt`. The generated table is
already included; rerun the notebook only when changing the variant source or
window selection.

## Train the standard model

The repository includes a selected standard checkpoint. To retrain standard
C.Origami with the downloaded bulk GM12878 inputs, submit:

```bash
sbatch src/training/corigami_train.sh
```

Training results are written to `outputs/training/standard/`.

## Run Plan A prediction

Select the number of ranked SNP-density regions with `TOP_N`:

```bash
snakemake --snakefile src/prediction/run_top_pred.smk --config TOP_N=50
```

The workflow writes paternal, maternal, bulk (`all`), and merged dscNanoATAC
predictions to `outputs/prediction/plan-a/`. Full execution requires the
configured C.Origami environment, GPU resources, and downloaded Zenodo inputs.

## Evaluate Plan A

[`benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb`](benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb)
is the primary Plan A evaluation notebook. It compares paternal and maternal
predictions with their matching Dip3D haplotypes and compares bulk (`all`) and
merged predictions with the merged Dip3D reference. The principal measures are
the Stratified Correlation Coefficient (SCC) and insulation correlation, with
summaries across shared regions and SNP-dense subsets.

The notebook requires external Dip3D matrices that are not committed. See
[`benchmarks/README.md`](benchmarks/README.md) for reference mappings, exact
metric definitions, filtering rules, interpretation caveats, and the archived
experimental benchmark comparison.
````

- [ ] **Step 4: Run the focused README contract and the notebook-output contract**

Run:

```bash
python -m unittest -v \
  tests.test_repository_contract.RepositoryContractTest.test_top_level_readme_documents_only_plan_a_workflow \
  tests.test_repository_contract.RepositoryContractTest.test_notebook_outputs_are_unchanged
```

Expected: `OK` with two passing tests.

- [ ] **Step 5: Confirm that the primary README has no experimental runnable entry points**

Run:

```bash
if rg -n 'corigami_train_atac_only\.sh|run_top_pred_plan[EH]\.smk|plans_benchmark_workflow\.png' README.md; then
  exit 1
fi
rg -n 'Plan A \(Default\)|run_top_pred\.smk|corigami_predict_benchmark_dip3d_planA_merge\.ipynb|benchmarks/README\.md' README.md
```

Expected: the first search prints nothing; the second search prints the Plan A
workflow, evaluation notebook, and benchmark-guide references.

- [ ] **Step 6: Commit the Plan A-only README**

Run:

```bash
git add README.md tests/test_repository_contract.py
git commit -m "docs: focus primary guide on Plan A"
```

Expected: one commit containing only the README boundary and its contract test.

### Task 3: Align workflow and dependency documentation

**Files:**
- Modify: `docs/workflow.md`
- Modify: `docs/dependencies.md`
- Modify: `tests/test_repository_contract.py`

**Interfaces:**
- Consumes: `benchmarks/README.md` from Task 1 and the primary Plan A contract established in Task 2.
- Produces: a Plan A workflow guide and a dependency guide that clearly separates production requirements from experimental benchmark-only tooling.

- [ ] **Step 1: Add the failing supporting-document contract**

Append this method to `RepositoryContractTest`:

```python
    def test_supporting_docs_keep_experimental_plans_in_benchmarks(self):
        workflow = (ROOT / "docs/workflow.md").read_text()
        dependencies = (ROOT / "docs/dependencies.md").read_text()

        for phrase in (
            "Plan A (Default)",
            "src/prediction/run_top_pred.smk",
            "../benchmarks/README.md",
            "corigami_predict_benchmark_dip3d_planA_merge.ipynb",
        ):
            self.assertIn(phrase, workflow)
        self.assertNotIn("run_top_pred_planE.smk", workflow)
        self.assertNotIn("run_top_pred_planH.smk", workflow)

        self.assertIn("Benchmark-only dependencies", dependencies)
        self.assertIn("Plan E (All-hap.)", dependencies)
        self.assertIn("Plan H (No-CTCF)", dependencies)
        self.assertIn("../benchmarks/README.md", dependencies)
```

- [ ] **Step 2: Run the focused supporting-document test and verify that it fails**

Run:

```bash
python -m unittest -v \
  tests.test_repository_contract.RepositoryContractTest.test_supporting_docs_keep_experimental_plans_in_benchmarks
```

Expected: `FAIL` because the workflow currently contains runnable Plan E/H
Snakefile names and neither supporting document uses the new benchmark boundary.

- [ ] **Step 3: Replace the workflow guide with the Plan A production path**

Replace `docs/workflow.md` with this content:

````markdown
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
reproducing prediction with that checkpoint.

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

Zenodo bulk DNA + GM12878 tracks ----> standard training ----> checkpoint
                                                           |
ranked regions + bulk DNA/CTCF + GM12878 dscNanoATAC -------+
                                                           v
                                                  Plan A predictions
                                                           |
external Dip3D/reference matrices -------------------------+
                                                           v
                                                  Plan A evaluation
```
````

- [ ] **Step 4: Reorganize dependencies into production and benchmark-only sections**

Replace `docs/dependencies.md` with this content:

````markdown
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
````

- [ ] **Step 5: Run the supporting-document contract and full contract suite**

Run:

```bash
python -m unittest -v \
  tests.test_repository_contract.RepositoryContractTest.test_supporting_docs_keep_experimental_plans_in_benchmarks
python -m unittest -v tests.test_repository_contract
```

Expected: the focused test reports `OK`; the full suite reports all tests as
passing, including the unchanged notebook-output hashes.

- [ ] **Step 6: Commit the supporting documentation boundary**

Run:

```bash
git add docs/workflow.md docs/dependencies.md tests/test_repository_contract.py
git commit -m "docs: separate benchmark-only workflows"
```

Expected: one commit containing the supporting-document split and its contract
test.

### Task 4: Verify repository integrity and documentation links

**Files:**
- Verify: `README.md`
- Verify: `benchmarks/README.md`
- Verify: `benchmarks/images/plans_benchmark_workflow.png`
- Verify: `docs/workflow.md`
- Verify: `docs/dependencies.md`
- Verify: `tests/test_repository_contract.py`
- Preserve: both files matching `benchmarks/*.ipynb`

**Interfaces:**
- Consumes: all deliverables from Tasks 1-3.
- Produces: evidence that tests, LFS objects, local Markdown links, image bytes, notebook outputs, and Git state satisfy the approved design.

- [ ] **Step 1: Run the complete repository contract suite**

Run:

```bash
export PATH="$HOME/.local/bin:$PATH"
python -m unittest -v tests.test_repository_contract
```

Expected: all repository contract tests pass, including
`test_notebook_outputs_are_unchanged` and the three new documentation tests.

- [ ] **Step 2: Verify Git LFS objects and patch formatting**

Run:

```bash
git lfs fsck
git diff --check HEAD~3..HEAD
```

Expected: `git lfs fsck` reports that Git LFS objects are OK; `git diff --check`
prints no output and exits zero.

- [ ] **Step 3: Check every relative Markdown link target in the changed documents**

Run:

```bash
python - <<'PY'
import re
from pathlib import Path

files = [
    Path("README.md"),
    Path("benchmarks/README.md"),
    Path("docs/workflow.md"),
    Path("docs/dependencies.md"),
]
pattern = re.compile(r"!?\[[^]]*\]\(([^)]+)\)")
missing = []
for document in files:
    for raw_target in pattern.findall(document.read_text()):
        target = raw_target.split("#", 1)[0]
        if not target or "://" in target or target.startswith("mailto:"):
            continue
        resolved = (document.parent / target).resolve()
        if not resolved.exists():
            missing.append(f"{document}: {raw_target}")
if missing:
    raise SystemExit("Missing local Markdown targets:\n" + "\n".join(missing))
print("All local Markdown targets exist")
PY
```

Expected: `All local Markdown targets exist`.

- [ ] **Step 4: Verify the image move and remove every old-path reference**

Run:

```bash
printf '%s  %s\n' \
  '5b415f8aba20b37b144f780e3fe2159d18ef00c1333f39e885ed2573f3ebab61' \
  'benchmarks/images/plans_benchmark_workflow.png' | sha256sum -c -
test ! -e docs/images/plans_benchmark_workflow.png
if rg -n 'docs/images/plans_benchmark_workflow\.png' \
  README.md benchmarks docs tests; then
  exit 1
fi
```

Expected: the hash check reports `OK`; the old file is absent; `rg` prints no
matches.

- [ ] **Step 5: Inspect the final commit range and worktree**

Run:

```bash
git log --oneline --decorate -4
git status --short --branch
```

Expected: the log shows the three implementation commits after the plan commit,
and `git status` reports `main` ahead of `origin/main` with no worktree changes.

- [ ] **Step 6: Push the completed documentation changes**

Run:

```bash
git push origin main
```

Expected: the SSH remote advances `main` to the final documentation commit.

