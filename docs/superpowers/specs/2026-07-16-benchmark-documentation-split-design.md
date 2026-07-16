# Benchmark Documentation Split Design

## Goal

Make Plan A (Default) the only recommended training, prediction, and evaluation
workflow in the top-level README. Move the Plan A/E/H comparison and detailed
benchmark methodology into a self-contained `benchmarks/README.md`, while
preserving all scripts, checkpoints, notebooks, and notebook outputs at their
current paths.

## Audience and Scope

The top-level README serves users who want to run AS-C.Origami. It should guide
them through the standard C.Origami model, allele-specific GM12878 dscNanoATAC
inputs, Plan A prediction, and Plan A evaluation. Plan E (All-hap.) and Plan H
(No-CTCF) are experimental comparison workflows used only for benchmarking and
must not appear as recommended alternatives or runnable primary workflows in
the top-level README.

The benchmark README serves readers reproducing or interpreting the archived
Plan A evaluation and the experimental Plan A/E/H comparison. It must state
that Plan E and Plan H are not recommended user workflows.

## Documentation Structure

### Top-level `README.md`

The README will:

- retain the Plan A-only `docs/images/AS-COrigami_workflow.png` figure;
- describe Plan A as the recommended AS-C.Origami workflow;
- document only standard C.Origami training and
  `src/prediction/run_top_pred.smk` prediction commands;
- keep only Plan A-required download, input, model, and environment guidance in
  the runnable workflow;
- add a concise evaluation section for
  `benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb`;
- explain that this notebook compares paternal, maternal, bulk (`all`), and
  merged Plan A predictions with the corresponding Dip3D references using SCC
  and insulation correlation; and
- link to `benchmarks/README.md` for metric definitions and experimental plan
  comparisons.

The README will remove the Plan A/E/H comparison table and image, the ATAC-only
training command, the Plan E and Plan H prediction commands, and the Plan E
allele-specific input-generation instructions. Repository inventory entries may
still acknowledge that benchmark-only assets exist, but they must direct users
to the benchmark README and must not present them as part of the recommended
workflow.

### `benchmarks/README.md`

This new document will be the canonical benchmark entry point. It will include:

- a scope warning that Plan E and Plan H are experimental benchmark-only
  workflows;
- the Plan A/E/H alias and input comparison table;
- the benchmark workflow figure;
- the role of each notebook;
- prediction-to-reference mappings for paternal, maternal, bulk, and merged
  groups;
- the shared-window selection and external-input assumptions visible in the
  notebooks;
- detailed metric definitions, parameters, interpretation, and aggregation;
- the Plan E `all` and `merge` alias caveat; and
- pointers to prediction workflows, dependencies, retained notebook outputs,
  and generated benchmark artifacts.

The two notebooks remain unchanged:

- `corigami_predict_benchmark_dip3d_planA_merge.ipynb` is the primary Plan A
  evaluation notebook.
- `corigami_predict_benchmark_planAEH.ipynb` is the experimental comparison of
  Plans A, E, and H.

### Figures

`docs/images/plans_benchmark_workflow.png` will move to
`benchmarks/images/plans_benchmark_workflow.png`. The top-level Plan A figure
will remain at its current path. All Markdown links will be updated after the
move.

### `docs/workflow.md`

The workflow guide will describe the Plan A production path from the phased VCF
and ranked regions through standard training, Plan A prediction, and Plan A
evaluation. Detailed Plan E/H generation, training, and prediction descriptions
will be replaced with a link to `benchmarks/README.md`. This keeps a single
canonical explanation of the experimental plans.

`docs/dependencies.md` may retain technical inventory needed to reproduce the
archived benchmark scripts, but its benchmark-only dependencies must be labeled
as such and linked to the benchmark documentation.

## Benchmark Metric Definitions

The benchmark README will document only metrics and comparisons implemented by
the notebooks.

### Stratified Correlation Coefficient (SCC)

SCC is the HiCRep-style similarity between two contact matrices. Contacts are
stratified by genomic separation, a correlation is computed within each usable
distance stratum, and the stratum correlations are combined with variance- and
sample-size-derived weights. The notebooks operate at 10 kb resolution and
restrict the comparison to the configured genomic-distance range (up to 1 Mb in
the Plan A/E/H comparison). Higher SCC means more similar contact structure;
values are correlation coefficients and therefore nominally range from -1 to
1.

### Insulation Correlation

Each contact matrix is converted into an insulation-like track by aggregating
contacts across a local diagonal window. Reference matrices are smoothed as
configured in the notebooks, and the predicted and reference tracks are
compared with pairwise-complete Pearson correlation. Higher values mean that
the prediction better reproduces reference boundary and insulation variation.
The README will record the notebook window and smoothing parameters rather than
presenting them as universal defaults.

### Plan A Summaries

The Plan A notebook reports SCC and insulation correlation for paternal,
maternal, bulk (`all`), and merged predictions on the same available regions.
Paternal and maternal predictions are compared with matching Dip3D haplotypes;
bulk and merged predictions are compared with the Dip3D merged reference. It
summarizes all regions and the top 100 SNP-dense regions using group-level mean
and median values. It also evaluates the association between mean SNP density
and insulation correlation, including the notebook's filtered Pearson
correlation summary.

### Plan A/E/H Comparison Metrics

The comparison notebook reports:

- **Paternal-maternal SCC concordance:** SCC between paternal and maternal maps
  is calculated separately for Dip3D and predictions in each window; agreement
  across windows is summarized with Pearson correlation.
- **Matched and mismatched haplotype SCC:** paternal and maternal predictions
  are compared with both paternal and maternal Dip3D references, allowing the
  matched pairs to be contrasted with cross-haplotype pairs.
- **SCC versus merged Dip3D:** bulk and merged prediction matrices are compared
  with the merged Dip3D reference.
- **Insulation correlation:** each prediction type is compared with its mapped
  Dip3D reference using the insulation-track Pearson correlation.

For each applicable plan and prediction type, result tables record observation
count and mean/median metric values. Figures show scatter, box, or violin
summaries as implemented in the notebook. The documentation will distinguish
per-window SCC from the across-window Pearson concordance statistic.

### Alias and Interpretation Caveats

In the archived Plan A/E/H notebook, Plan E `all` and `merge` entries are aliases
of Plan A rather than independent Plan E predictions. They must be labeled as
aliases in the documentation and must not be interpreted as independent
evidence. Missing, filtered, or invalid windows reduce the metric-specific
observation count, so comparisons should use the reported `n` and shared-window
rules.

## Verification

Repository contract tests will enforce the documentation boundary by checking
that:

- the top-level README contains the Plan A prediction and evaluation notebook;
- the top-level README does not contain Plan E/H runnable prediction or
  ATAC-only training commands;
- `benchmarks/README.md` contains the plan aliases, benchmark-only warning,
  notebook links, metric names, and Plan E alias caveat;
- the moved benchmark image exists and all old references are removed; and
- notebook output hashes remain unchanged.

The existing repository contract suite, `git lfs fsck`, Markdown link/path
checks, `git diff --check`, and notebook output hash test will be run before the
change is considered complete.
