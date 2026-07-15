# README Workflow Documentation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an English AS-C.Origami overview, Plan A/E/H comparison, upstream environment guidance, and the two supplied workflow figures to the repository README.

**Architecture:** Keep the README as the main entry point and store presentation assets under `docs/images/`. The update is documentation-only: it adds the approved prose and figures without changing workflow code, models, data, notebooks, or runtime paths.

**Tech Stack:** Git, Git LFS-aware repository, Markdown, PNG, Python `unittest`

## Global Constraints

- Keep all new README prose in English.
- Preserve the supplied filenames `AS-COrigami_workflow.png` and `plans_benchmark_workflow.png`.
- Define Plan A as `Default`, Plan E as `All-hap.`, and Plan H as `No-CTCF`.
- Label Plan A (`Default`) as the recommended starting workflow.
- Link C.Origami to <https://github.com/tanjimin/C.Origami> and direct users to its environment setup instructions.
- Store both PNG files as normal Git files, not Git LFS objects.
- Do not alter workflow code, model files, data files, notebook outputs, or runtime paths.

---

### Task 1: Add Workflow Figures

**Files:**
- Create: `docs/images/AS-COrigami_workflow.png`
- Create: `docs/images/plans_benchmark_workflow.png`
- Source: `../AS-COrigami_workflow.png` relative to the repository root
- Source: `../plans_benchmark_workflow.png` relative to the repository root

**Interfaces:**
- Consumes: The two supplied PNG files beside the repository.
- Produces: Stable repository-relative image paths consumed by `README.md`.

- [ ] **Step 1: Confirm source assets and hashes**

Run:

```bash
test -f ../AS-COrigami_workflow.png
test -f ../plans_benchmark_workflow.png
sha256sum ../AS-COrigami_workflow.png ../plans_benchmark_workflow.png
```

Expected hashes:

```text
fb111c2daeb1c04977e6477b7f12584efda7cb705671aea347f859ad0ffd71db  ../AS-COrigami_workflow.png
5b415f8aba20b37b144f780e3fe2159d18ef00c1333f39e885ed2573f3ebab61  ../plans_benchmark_workflow.png
```

- [ ] **Step 2: Copy the figures into the documentation tree**

Run:

```bash
mkdir -p docs/images
cp ../AS-COrigami_workflow.png docs/images/AS-COrigami_workflow.png
cp ../plans_benchmark_workflow.png docs/images/plans_benchmark_workflow.png
```

- [ ] **Step 3: Verify copied bytes and Git storage policy**

Run:

```bash
cmp ../AS-COrigami_workflow.png docs/images/AS-COrigami_workflow.png
cmp ../plans_benchmark_workflow.png docs/images/plans_benchmark_workflow.png
git check-attr filter -- docs/images/AS-COrigami_workflow.png docs/images/plans_benchmark_workflow.png
```

Expected: both `cmp` commands exit 0, and neither image reports `filter: lfs`.

- [ ] **Step 4: Commit the figures**

```bash
git add docs/images/AS-COrigami_workflow.png docs/images/plans_benchmark_workflow.png
git commit -m "docs: add AS-C.Origami workflow figures"
```

### Task 2: Add README Overview and Plan Comparison

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: The figure paths created in Task 1 and the Plan definitions in the approved design.
- Produces: The repository's user-facing workflow overview and plan selection guidance.

- [ ] **Step 1: Insert the overview after the opening summary**

Add this section before `## Repository layout`:

```markdown
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
```

- [ ] **Step 2: Inspect the resulting README structure**

Run:

```bash
sed -n '1,130p' README.md
```

Expected: `Overview` and `Prediction plans` appear after the opening summary and before `Repository layout`; the existing sections remain intact.

- [ ] **Step 3: Commit the overview and plan comparison**

```bash
git add README.md
git commit -m "docs: explain AS-C.Origami prediction plans"
```

### Task 3: Add Environment Setup Guidance

**Files:**
- Modify: `README.md`

**Interfaces:**
- Consumes: The upstream C.Origami repository URL and existing `docs/dependencies.md`.
- Produces: A clear prerequisite immediately before data preparation and execution instructions.

- [ ] **Step 1: Add environment guidance before bulk-data download**

Insert this section immediately before `## Download the C.Origami bulk data`:

```markdown
## Environment setup

Before running AS-C.Origami, follow the installation and environment setup
steps in the upstream [C.Origami repository](https://github.com/tanjimin/C.Origami)
to configure the `corigami` environment. The training launchers use that
environment by default; set `CORIGAMI_ENV` if it has a different name.

Install the additional workflow and input-generation dependencies, including
Snakemake, as listed in [`docs/dependencies.md`](docs/dependencies.md).
```

- [ ] **Step 2: Confirm the environment section is correctly positioned**

Run:

```bash
rg -n '^## (Inputs already included|Environment setup|Download the C\.Origami bulk data|Run training and prediction)' README.md
```

Expected: `Environment setup` occurs after the included-input provenance and before data download and execution sections.

- [ ] **Step 3: Commit the environment guidance**

```bash
git add README.md
git commit -m "docs: link C.Origami environment setup"
```

### Task 4: Verify and Publish Documentation

**Files:**
- Verify: `README.md`
- Verify: `docs/images/AS-COrigami_workflow.png`
- Verify: `docs/images/plans_benchmark_workflow.png`
- Verify: `tests/test_repository_contract.py`

**Interfaces:**
- Consumes: Documentation produced by Tasks 1-3.
- Produces: A verified commit series on the private GitHub repository's `main` branch.

- [ ] **Step 1: Verify README requirements and image links**

Run:

```bash
rg -n 'AS-C\.Origami is a workflow|dscNanoATAC|Plan A|Default|Plan E|All-hap\.|Plan H|No-CTCF|tanjimin/C\.Origami' README.md
test -f docs/images/AS-COrigami_workflow.png
test -f docs/images/plans_benchmark_workflow.png
```

Expected: every required term is present and both file checks exit 0.

- [ ] **Step 2: Verify image integrity**

Run:

```bash
printf '%s  %s\n' \
  fb111c2daeb1c04977e6477b7f12584efda7cb705671aea347f859ad0ffd71db \
  docs/images/AS-COrigami_workflow.png \
  5b415f8aba20b37b144f780e3fe2159d18ef00c1333f39e885ed2573f3ebab61 \
  docs/images/plans_benchmark_workflow.png | sha256sum -c -
```

Expected: both files report `OK`.

- [ ] **Step 3: Run repository verification**

Run:

```bash
export PATH="$HOME/.local/bin:$PATH"
python -m unittest -v tests.test_repository_contract
git lfs fsck
git diff --check origin/main...HEAD
git status --short --branch
```

Expected: 11 tests pass, `Git LFS fsck OK`, no diff-check errors, and the working tree is clean with `main` ahead of `origin/main` only by the approved documentation commits.

- [ ] **Step 4: Push and verify the private GitHub repository**

Use the authenticated SSH transport because the configured local HTTPS proxy is known to terminate GitHub TLS connections:

```bash
export PATH="$HOME/.local/bin:$PATH"
git push git@github.com:LuJiansen/AS-C.Origami.git main:main
REMOTE_SHA="$(git ls-remote git@github.com:LuJiansen/AS-C.Origami.git refs/heads/main | awk '{print $1}')"
test "$(git rev-parse HEAD)" = "$REMOTE_SHA"
env -u HTTP_PROXY -u HTTPS_PROXY -u ALL_PROXY \
  -u http_proxy -u https_proxy -u all_proxy \
  gh api repos/LuJiansen/AS-C.Origami --jq '.visibility'
```

Expected: the push succeeds, local and remote SHAs match, and the API prints `private`.
