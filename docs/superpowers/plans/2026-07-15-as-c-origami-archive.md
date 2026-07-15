# AS-C.Origami Archive Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a traceable local archive of the eight requested AS-C.Origami workflow files and publish it as the private GitHub repository `LuJiansen/AS-C.Origami`.

**Architecture:** Preserve each requested source file byte-for-byte under a stage-specific directory, then document how training, SNP-density selection, Plan A/E/H prediction, and benchmarking connect. Keep models, datasets, generated results, and unrequested helper programs external; record their paths and limitations instead of copying them.

**Tech Stack:** Bash, Snakemake, Jupyter notebooks (R/IRkernel), Git, GitHub CLI, SHA-256, jq

## Global Constraints

- Copy exactly the eight files named in the approved design.
- Preserve all existing notebook outputs.
- Do not format, parameterize, execute, or otherwise modify archived source files.
- Preserve absolute cluster paths in archived files and explain them in documentation.
- Do not add checkpoints, BigWig files, prediction matrices, reference data, or unrequested helper scripts.
- Publish only to a GitHub repository named `AS-C.Origami` with visibility `PRIVATE`.
- Do not overwrite or force-push an existing remote repository.

---

### Task 1: Archive source files with provenance

**Files:**
- Create: `training/corigami_train.sh`
- Create: `training/corigami_train_atac_only.sh`
- Create: `prediction/run_top_pred.smk`
- Create: `prediction/run_top_pred_planE.smk`
- Create: `prediction/run_top_pred_planH.smk`
- Create: `snp-density/SNP_density.ipynb`
- Create: `benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb`
- Create: `benchmarks/corigami_predict_benchmark_planAEH.ipynb`
- Create: `docs/source-manifest.tsv`

**Interfaces:**
- Consumes: the eight absolute source paths listed in `docs/source-manifest.tsv`
- Produces: byte-identical archived files and a four-column provenance manifest (`category`, `repository_path`, `source_path`, `sha256`)

- [ ] **Step 1: Create stage directories and the expected provenance manifest**

Create `training`, `prediction`, `snp-density`, and `benchmarks`. Add this exact tab-separated manifest:

```tsv
category	repository_path	source_path	sha256
training	training/corigami_train.sh	/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/corigami_train.sh	e846bdfe75805aa79fff5f28f904062e3b3886d604a48621508317eb01e64273
training	training/corigami_train_atac_only.sh	/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/corigami_train_atac_only.sh	833c2685276c23f01dd6b8fd12e57766bddf185832ae7c2f3d7d95de85267c65
prediction	prediction/run_top_pred.smk	/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/run_top_pred.smk	1cdc626227bc3c84c8345ef83b383d9cc9b780416e339483f03e6027911b245a
prediction	prediction/run_top_pred_planE.smk	/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/run_top_pred_planE.smk	252d2950c0333f3a5342a767455c6dc3326f450800e5f17f6a92bf0c07ccfcfd
prediction	prediction/run_top_pred_planH.smk	/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/run_top_pred_planH.smk	7189f2af74b094c636987b5966089c351730211a91cbe95da92365260e7875d0
snp-density	snp-density/SNP_density.ipynb	/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/SNP_density.ipynb	27db4337b82a8f53995cf1799196075cd2141b0d5440bb64051ade640b232b99
benchmark	benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb	/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LJS/10XATAC/analysis/corigami_predict_benchmark_dip3d_planA_merge.ipynb	7e7c914d5487b1426eee95d2f66d8fa8a8307ff1802d945be93e6698fc0a11c7
benchmark	benchmarks/corigami_predict_benchmark_planAEH.ipynb	/home/tangfuchou_pkuhpc/tangfuchou_test/gpfs1/lujiansen/project/LW_TEST/10XATAC/analysis/corigami_predict_benchmark_planAEH.ipynb	c50ae41e859651278f585cd4f570cb96fbe1b93dba2cdbdad0a9c685ac74f9ba
```

- [ ] **Step 2: Verify source files still match the approved hashes**

Run:

```bash
tail -n +2 docs/source-manifest.tsv | while IFS=$'\t' read -r category repository_path source_path expected; do
    actual=$(sha256sum "$source_path" | awk '{print $1}')
    test "$actual" = "$expected" || {
        echo "source changed: $source_path" >&2
        exit 1
    }
done
```

Expected: exit 0 with no output. If a source changed, stop and update the design provenance only after reviewing that change.

- [ ] **Step 3: Copy each source to its manifest destination**

Run:

```bash
tail -n +2 docs/source-manifest.tsv | while IFS=$'\t' read -r category repository_path source_path expected; do
    cp --preserve=mode,timestamps "$source_path" "$repository_path"
done
```

Expected: all eight repository paths exist; notebook outputs remain embedded because files are copied without transformation.

- [ ] **Step 4: Verify every archived copy is byte-identical**

Run:

```bash
tail -n +2 docs/source-manifest.tsv | while IFS=$'\t' read -r category repository_path source_path expected; do
    actual=$(sha256sum "$repository_path" | awk '{print $1}')
    test "$actual" = "$expected" || {
        echo "archive mismatch: $repository_path" >&2
        exit 1
    }
done
```

Expected: exit 0 with no output.

- [ ] **Step 5: Commit the archive and manifest**

```bash
git add training prediction snp-density benchmarks docs/source-manifest.tsv
git commit -m "chore: archive AS-C.Origami workflow sources"
```

Expected: one commit containing exactly the eight archived files and the manifest.

---

### Task 2: Document workflow and dependencies

**Files:**
- Create: `README.md`
- Create: `docs/workflow.md`
- Create: `docs/dependencies.md`
- Create: `.gitignore`

**Interfaces:**
- Consumes: stage directories and provenance manifest from Task 1
- Produces: repository navigation, an end-to-end workflow summary, an external-dependency inventory, and guards against large generated files

- [ ] **Step 1: Write the repository README**

Create `README.md` with this content:

```markdown
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
```

- [ ] **Step 2: Write the workflow summary**

Create `docs/workflow.md` with this content:

````markdown
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
````

- [ ] **Step 3: Write the external dependency inventory**

Create `docs/dependencies.md` with this content:

```markdown
# Dependencies and environment

## Software

- C.Origami command-line tools, including `corigami-train` and `corigami-predict`
- Conda environment named `corigami`
- Python/PyTorch and the local ATAC-only training and inference programs
- Snakemake and a GPU-enabled cluster execution environment
- R with IRkernel and the packages loaded by the benchmark notebooks
- Python packages loaded through `reticulate` in the benchmark notebooks

Exact package versions were not captured by the requested files and are therefore not inferred here.

## External code

- `/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/train_atac_only.py`
- `/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/predict_atac_only.py`

These programs are referenced by the archived launchers but are outside the explicitly requested archive scope.

## External data

The workflows require model checkpoints, haplotype and bulk DNA sequences, allele-specific and bulk ATAC BigWig tracks, CTCF tracks, chromosome sizes, ranked SNP-density windows, Dip3D reference matrices, blacklist intervals, and prediction `.npy` files. These are intentionally excluded because they are generated data, reference data, or large binary artifacts.

## Cluster-specific paths

The archived files retain absolute paths under `/gpfs1` and `/home/tangfuchou_pkuhpc`. They describe the environment in which the workflow was used and must be reviewed before running on another system. No path has been parameterized in this archive.

## Execution limits

Notebook outputs are retained for reference, but the notebooks were not re-executed during archiving. Snakemake dry-runs are also not part of archive verification because top-level workflow evaluation reads external files.

The archived `run_top_pred_planE.smk` currently references `seq` and `ctcf` in its `merge_pred` rule even though only haplotype-specific `seq_pat`, `seq_mat`, `ctcf_pat`, and `ctcf_mat` variables are declared. This is preserved as source provenance rather than silently corrected; review and resolve it before executing Plan E.
```

- [ ] **Step 4: Add generated-data guards**

Create `.gitignore` with this content:

```gitignore
# Model and genomic data
*.ckpt
*.bw
*.bigWig
*.bedGraph
*.fasta
*.fa

# Generated predictions and analysis objects
*.npy
*.npz
*.RData
*.RDataTmp
*.qs

# Notebook and local environment state
.ipynb_checkpoints/
.Rhistory
.RData
__pycache__/
*.py[cod]

# Workflow outputs and logs
predict/
predict_*/
.snakemake/
logs/
```

- [ ] **Step 5: Verify documentation coverage**

Run:

```bash
for path in \
  training/corigami_train.sh \
  training/corigami_train_atac_only.sh \
  prediction/run_top_pred.smk \
  prediction/run_top_pred_planE.smk \
  prediction/run_top_pred_planH.smk \
  snp-density/SNP_density.ipynb \
  benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb \
  benchmarks/corigami_predict_benchmark_planAEH.ipynb; do
    rg -F "$(basename "$path")" README.md docs >/dev/null || {
        echo "undocumented: $path" >&2
        exit 1
    }
done
git diff --check
```

Expected: exit 0 with no output.

- [ ] **Step 6: Commit repository documentation**

```bash
git add README.md .gitignore docs/workflow.md docs/dependencies.md
git commit -m "docs: summarize AS-C.Origami workflow"
```

Expected: one documentation commit.

---

### Task 3: Verify and publish the private repository

**Files:**
- Verify: all tracked repository files
- Modify external state: private GitHub repository `LuJiansen/AS-C.Origami`

**Interfaces:**
- Consumes: completed local `main` branch from Tasks 1 and 2 and an authenticated `gh` session for `LuJiansen`
- Produces: a clean, validated local repository and a synchronized private GitHub remote

- [ ] **Step 1: Validate archived formats and provenance**

Run:

```bash
bash -n training/corigami_train.sh training/corigami_train_atac_only.sh
jq empty \
  snp-density/SNP_density.ipynb \
  benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb \
  benchmarks/corigami_predict_benchmark_planAEH.ipynb
tail -n +2 docs/source-manifest.tsv | while IFS=$'\t' read -r category repository_path source_path expected; do
    test "$(sha256sum "$repository_path" | awk '{print $1}')" = "$expected" || exit 1
done
```

Expected: exit 0 with no output.

- [ ] **Step 2: Check scope, file sizes, and credentials**

Run:

```bash
test "$(tail -n +2 docs/source-manifest.tsv | wc -l)" -eq 8
test -z "$(find . -path ./.git -prune -o -type f -size +99M -print)"
test -z "$(find . -path ./.git -prune -o -type f \( -name '*.ckpt' -o -name '*.bw' -o -name '*.npy' -o -name '*.RData' -o -name '*.qs' \) -print)"
rg -n -i '(github_pat_|ghp_[A-Za-z0-9]{20,}|api[_-]?key[[:space:]]*[:=]|password[[:space:]]*[:=]|secret[[:space:]]*[:=])' . \
  --glob '!.git/**' --glob '!docs/superpowers/**' && exit 1 || test $? -eq 1
git diff --check
git status --short
```

Expected: no file above 99 MB (and therefore no file at GitHub's 100 MB limit), no excluded binary artifacts, no credential pattern, no whitespace error, and an empty `git status --short`.

- [ ] **Step 3: Authenticate GitHub CLI**

Run:

```bash
gh auth status -h github.com
```

Expected: authenticated as `LuJiansen`. The current token is known to be invalid; if the check fails, run `gh auth login -h github.com -p https -w` and complete the browser/device authorization before continuing.

- [ ] **Step 4: Check for an existing remote repository without changing it**

Run:

```bash
gh repo view LuJiansen/AS-C.Origami --json nameWithOwner,visibility,url,defaultBranchRef
```

Expected when absent: a not-found error, allowing repository creation. If present, require `nameWithOwner` to equal `LuJiansen/AS-C.Origami`, `visibility` to equal `PRIVATE`, and do not push until its branch history has been inspected for conflicts.

- [ ] **Step 5: Create and push when the repository is absent**

Run:

```bash
gh repo create LuJiansen/AS-C.Origami --private --source=. --remote=origin --push
```

Expected: the private repository is created, `origin` is configured, and local `main` is pushed. If the repository already exists and has no conflicting history, add its SSH or HTTPS URL as `origin` and use a normal `git push -u origin main`; never use `--force`.

- [ ] **Step 6: Verify remote privacy and synchronization**

Run:

```bash
test "$(gh repo view LuJiansen/AS-C.Origami --json visibility --jq .visibility)" = "PRIVATE"
test "$(git rev-parse HEAD)" = "$(git ls-remote origin refs/heads/main | awk '{print $1}')"
git status --short --branch
```

Expected: visibility check passes, local and remote commit hashes match, and status reports `main` tracking `origin/main` with no changes.
