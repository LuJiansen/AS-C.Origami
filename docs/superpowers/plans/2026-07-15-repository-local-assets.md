# Repository-Local Workflow Assets Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make AS-C.Origami training, Plan A/E/H prediction, SNP-density generation, and benchmark analysis use a documented repository-local `src/` layout, with selected GM12878 assets stored through Git LFS and reproducible generation instructions for omitted data.

**Architecture:** Every executable entry point derives the repository root from its own file location and reads immutable inputs under `src/`, while generated training and prediction products go under ignored `outputs/`. Small code and reference files use normal Git, checkpoints/BigWigs/VCF files use Git LFS, Zenodo bulk data stays downloadable, and diploid DNA plus Plan E CTCF tracks stay reproducible from checked-in generation code.

**Tech Stack:** Bash, Python 3, Snakemake, Jupyter notebook JSON, R/IRkernel, C.Origami, bcftools/samtools, pyBigWig/pysam, Git LFS, GitHub CLI, SHA-256

## Global Constraints

- Keep training and prediction code under `src/training/` and `src/prediction/` and record every imported file's source.
- Put selected model weights and input data under `src/models/` and `src/data/`; never write new run products into those directories.
- Store training outputs in `outputs/training/{standard,atac-only}/` and Plan A/E/H predictions in `outputs/prediction/plan-{a,e,h}/`.
- Preserve every existing output object in all three notebooks byte-for-byte at the parsed JSON level.
- Fix Plan E `merge_pred` to use bulk DNA and bulk CTCF; paternal and maternal rules continue to use diploid DNA and allele-specific CTCF.
- Upload the two checkpoints, three GM12878 dscNanoATAC BigWigs, phased VCF/index, SNP-region table, and chromosome lengths.
- Name the dscNanoATAC tracks `GM12878_dscNanoATAC_{paternal,maternal,merged}.bw`.
- Track `*.ckpt`, `*.bw`, `*.vcf.gz`, and `*.vcf.gz.tbi` assets through Git LFS before adding them to Git.
- Do not upload Zenodo bulk C.Origami data, diploid DNA, generated SNP-only VCF, or Plan E CTCF BigWigs.
- Document Zenodo bulk data source as `https://zenodo.org/record/7226561/files/corigami_data_gm12878_add_on.tar.gz?download=1`.
- Document phased VCF source as `https://github.com/Illumina/PlatinumGenomes`.
- Keep external Dip3D, blacklist, reference-matrix, and benchmark-only inputs as documented external dependencies.
- Publish only to the existing private repository `LuJiansen/AS-C.Origami`; do not force-push.

---

### Task 1: Establish the repository contract and import source code

**Files:**
- Create: `tests/test_repository_contract.py`
- Create: `tests/notebook-output-hashes.tsv`
- Move: `training/corigami_train.sh` to `src/training/corigami_train.sh`
- Move: `training/corigami_train_atac_only.sh` to `src/training/corigami_train_atac_only.sh`
- Move: `prediction/run_top_pred.smk` to `src/prediction/run_top_pred.smk`
- Move: `prediction/run_top_pred_planE.smk` to `src/prediction/run_top_pred_planE.smk`
- Move: `prediction/run_top_pred_planH.smk` to `src/prediction/run_top_pred_planH.smk`
- Create from source: `src/training/train_atac_only.py`
- Create from source: `src/prediction/predict_atac_only.py`
- Create from source: `src/generation/diploid-dna/01_build_haplotype_fasta.sh`
- Create from source: `src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py`
- Create from source: `src/generation/plan-e-ctcf/MA0139.1.meme`
- Create: `src/data/corigami_data/README.md`

**Interfaces:**
- Consumes: current archived workflow files and the five confirmed external helper-code paths in the approved design
- Produces: the final source-tree locations and `python -m unittest` contract used by all later tasks

- [ ] **Step 1: Write the notebook-output baseline and failing layout test**

Create `tests/notebook-output-hashes.tsv` exactly as:

```tsv
path	sha256
snp-density/SNP_density.ipynb	c50e8644153114fd815f12844bcbf1daabca22558e2a743640b4b19de15535ff
benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb	d6360144b6d591f3024e3ae8f1664e318db3546b084137670636e89c64f2f100
benchmarks/corigami_predict_benchmark_planAEH.ipynb	0fb63042c07273921aea322010e169abce4abc58b62fedfa061c6ba32f479764
```

Create `tests/test_repository_contract.py` with:

```python
import csv
import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class RepositoryContractTest(unittest.TestCase):
    def test_required_source_files_exist(self):
        expected = [
            "src/training/corigami_train.sh",
            "src/training/corigami_train_atac_only.sh",
            "src/training/train_atac_only.py",
            "src/prediction/run_top_pred.smk",
            "src/prediction/run_top_pred_planE.smk",
            "src/prediction/run_top_pred_planH.smk",
            "src/prediction/predict_atac_only.py",
            "src/generation/diploid-dna/01_build_haplotype_fasta.sh",
            "src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py",
            "src/generation/plan-e-ctcf/MA0139.1.meme",
            "src/data/corigami_data/README.md",
        ]
        missing = [path for path in expected if not (ROOT / path).is_file()]
        self.assertEqual([], missing)

    def test_legacy_entrypoint_directories_are_absent(self):
        self.assertFalse((ROOT / "training").exists())
        self.assertFalse((ROOT / "prediction").exists())

    def test_notebook_outputs_are_unchanged(self):
        baseline = ROOT / "tests/notebook-output-hashes.tsv"
        with baseline.open(newline="") as handle:
            rows = csv.DictReader(handle, delimiter="\t")
            for row in rows:
                notebook = json.loads((ROOT / row["path"]).read_text())
                outputs = [
                    cell.get("outputs")
                    for cell in notebook["cells"]
                    if cell.get("cell_type") == "code"
                ]
                payload = json.dumps(
                    outputs, ensure_ascii=False, separators=(",", ":")
                ).encode() + b"\n"
                self.assertEqual(
                    row["sha256"], hashlib.sha256(payload).hexdigest(), row["path"]
                )


if __name__ == "__main__":
    unittest.main()
```

- [ ] **Step 2: Run the contract test and confirm the new layout is missing**

Run:

```bash
python -m unittest tests.test_repository_contract -v
```

Expected: `test_required_source_files_exist` and `test_legacy_entrypoint_directories_are_absent` fail; the notebook-output test passes.

- [ ] **Step 3: Move archived entry points and import helper code after checking source hashes**

Run:

```bash
test "$(sha256sum /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/train_atac_only.py | cut -d' ' -f1)" = e94319dc19a19172095cfeaaaa0dfddef5778240b598bd81405378040e07eacb
test "$(sha256sum /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/predict_atac_only.py | cut -d' ' -f1)" = aeee5b32b3bc27fc399b5ca32ae1a366cac5eba7ed7bb121b78522d84d90ec32
test "$(sha256sum /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/allele_specific/01_build_haplotype_fasta.sh | cut -d' ' -f1)" = 4b9d3c800c3e4764ab2cc42082ba001eb613531c17995388ff98bdac64ce3420
test "$(sha256sum /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/allele_specific/06_continuous_pwm_ctcf.py | cut -d' ' -f1)" = 0e8588a49da786c17adbc7d727b803cfb500e4e41586ca41cc6f84088c5683b9
test "$(sha256sum /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/allele_specific/MA0139.1.meme | cut -d' ' -f1)" = ff882efb8c83632af3b880f60d865b125276d7ccaf22a4706da217685dab4fc0
mkdir -p src/training src/prediction src/generation/diploid-dna src/generation/plan-e-ctcf src/data/corigami_data
git mv training/corigami_train.sh training/corigami_train_atac_only.sh src/training/
git mv prediction/run_top_pred.smk prediction/run_top_pred_planE.smk prediction/run_top_pred_planH.smk src/prediction/
rmdir training prediction
cp --preserve=mode,timestamps /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/train_atac_only.py src/training/
cp --preserve=mode,timestamps /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/predict_atac_only.py src/prediction/
cp --preserve=mode,timestamps /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/allele_specific/01_build_haplotype_fasta.sh src/generation/diploid-dna/
cp --preserve=mode,timestamps /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/allele_specific/06_continuous_pwm_ctcf.py src/generation/plan-e-ctcf/
cp --preserve=mode,timestamps /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/allele_specific/MA0139.1.meme src/generation/plan-e-ctcf/
```

Create `src/data/corigami_data/README.md` with:

```markdown
# C.Origami GM12878 bulk data

Download the public archive documented in the repository README and extract it so that this directory contains `data/hg38/dna_sequence/` and `data/hg38/gm12878/genomic_features/`. The `data/` directory is intentionally excluded from Git.
```

- [ ] **Step 4: Re-run tests and commit the source-tree migration**

Run:

```bash
python -m unittest tests.test_repository_contract -v
git add src tests
git commit -m "refactor: organize workflow sources under src"
```

Expected: all three tests pass and the commit records moves rather than duplicate legacy entry points.

---

### Task 2: Make training launchers repository-relative

**Files:**
- Modify: `src/training/corigami_train.sh`
- Modify: `src/training/corigami_train_atac_only.sh`
- Modify: `tests/test_repository_contract.py`

**Interfaces:**
- Consumes: repository root inferred from `src/training/<script>`
- Produces: standard and ATAC-only runs writing to `outputs/training/{standard,atac-only}`

- [ ] **Step 1: Add a failing training-path test**

Add this method to `RepositoryContractTest`:

```python
    def test_training_launchers_use_repository_paths(self):
        standard = (ROOT / "src/training/corigami_train.sh").read_text()
        atac_only = (ROOT / "src/training/corigami_train_atac_only.sh").read_text()
        for text in (standard, atac_only):
            self.assertIn('REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"', text)
            self.assertIn('${REPO_ROOT}/src/data/corigami_data/data', text)
            self.assertNotIn("/software/corigami", text)
        self.assertIn('${REPO_ROOT}/outputs/training/standard', standard)
        self.assertIn('${REPO_ROOT}/src/training/train_atac_only.py', atac_only)
        self.assertIn('${REPO_ROOT}/outputs/training/atac-only', atac_only)
```

Run `python -m unittest tests.test_repository_contract.RepositoryContractTest.test_training_launchers_use_repository_paths -v`.

Expected: failure because the launchers still use working-directory-relative and absolute cluster paths.

- [ ] **Step 2: Update both launchers without changing SLURM resources or model parameters**

Immediately after the `#SBATCH` block, use:

```bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
```

In `corigami_train.sh`, create and use:

```bash
OUTPUT_DIR="${REPO_ROOT}/outputs/training/standard"
mkdir -p "${OUTPUT_DIR}"

corigami-train \
    --data-root "${REPO_ROOT}/src/data/corigami_data/data" \
    --assembly hg38 \
    --celltype gm12878 \
    --save_path "${OUTPUT_DIR}" \
    --num-gpu 1 > "${OUTPUT_DIR}/training.log" 2>&1
```

In `corigami_train_atac_only.sh`, retain the environment initialization but remove `cd /gpfs1/.../software/corigami`; replace the Python call with:

```bash
OUTPUT_DIR="${REPO_ROOT}/outputs/training/atac-only"
mkdir -p "${OUTPUT_DIR}"

python "${REPO_ROOT}/src/training/train_atac_only.py" \
    --data-root "${REPO_ROOT}/src/data/corigami_data/data" \
    --assembly hg38 \
    --celltype gm12878 \
    --save_path "${OUTPUT_DIR}" \
    --num-gpu 1 \
    --batch-size 4 \
    --num-workers 2 \
    --ddp-disabled &> "${OUTPUT_DIR}/training.log"
```

- [ ] **Step 3: Verify shell syntax and commit**

Run:

```bash
bash -n src/training/corigami_train.sh
bash -n src/training/corigami_train_atac_only.sh
python -m unittest tests.test_repository_contract -v
git add src/training tests/test_repository_contract.py
git commit -m "refactor: use repository paths for training"
```

Expected: shell parsing and all contract tests pass.

---

### Task 3: Make Plan A/E/H prediction workflows repository-relative

**Files:**
- Modify: `src/prediction/run_top_pred.smk`
- Modify: `src/prediction/run_top_pred_planE.smk`
- Modify: `src/prediction/run_top_pred_planH.smk`
- Modify: `tests/test_repository_contract.py`

**Interfaces:**
- Consumes: assets under `src/models/`, `src/data/`, and generated Zenodo-layout directories
- Produces: Plan A/E/H `.npy` files under `outputs/prediction/plan-{a,e,h}`

- [ ] **Step 1: Add failing workflow path and Plan E merge tests**

Add:

```python
    def test_prediction_workflows_use_repository_paths(self):
        expected_outputs = {
            "run_top_pred.smk": "outputs/prediction/plan-a",
            "run_top_pred_planE.smk": "outputs/prediction/plan-e",
            "run_top_pred_planH.smk": "outputs/prediction/plan-h",
        }
        for name, output in expected_outputs.items():
            text = (ROOT / "src/prediction" / name).read_text()
            self.assertIn("Path(workflow.snakefile).resolve().parents[2]", text)
            self.assertIn(output, text)
            self.assertNotIn("/gpfs1/", text)
            self.assertNotIn("/home/", text)

    def test_plan_e_merge_uses_bulk_sequence_and_ctcf(self):
        text = (ROOT / "src/prediction/run_top_pred_planE.smk").read_text()
        merge_rule = text.split("rule merge_pred:", 1)[1]
        self.assertIn("seq   = bulk_seq", merge_rule)
        self.assertIn("ctcf  = bulk_ctcf", merge_rule)
```

Run the two tests directly; expect both to fail.

- [ ] **Step 2: Define one path contract at the top of each Snakefile**

Add `from pathlib import Path`, then define:

```python
REPO_ROOT = Path(workflow.snakefile).resolve().parents[2]
SRC = REPO_ROOT / "src"
DATA = SRC / "data"
CORIGAMI_DATA = DATA / "corigami_data" / "data"
REGION_LIST = DATA / "regions" / "GM12878_2M_10k_snp_density_summary.txt"
CHROM_SIZES = DATA / "reference" / "GRCh38.chrom.sizes"
DSC_ATAC = DATA / "dscNanoATAC"
```

Use `str(...)` for every path passed to Snakemake. Plan-specific output roots are:

```python
# Plan A
OUTPUT_ROOT = REPO_ROOT / "outputs" / "prediction" / "plan-a"

# Plan E
OUTPUT_ROOT = REPO_ROOT / "outputs" / "prediction" / "plan-e"

# Plan H
OUTPUT_ROOT = REPO_ROOT / "outputs" / "prediction" / "plan-h"
```

- [ ] **Step 3: Replace Plan A inputs and outputs**

Use this input mapping:

```python
model = str(SRC / "models" / "standard" / "epoch=78-step=47004.ckpt")
seq = str(CORIGAMI_DATA / "hg38" / "dna_sequence")
ctcf = str(CORIGAMI_DATA / "hg38" / "gm12878" / "genomic_features" / "ctcf_log2fc.bw")
atac = str(CORIGAMI_DATA / "hg38" / "gm12878" / "genomic_features" / "atac.bw")
pat_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_paternal.bw")
mat_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_maternal.bw")
merge_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_merged.bw")
region_list = str(REGION_LIST)
chrom_sizes = str(CHROM_SIZES)
```

Define output templates with `str(OUTPUT_ROOT / "GM12878_pat/prediction/npy/{region}.npy")` and the existing `GM12878_mat`, `GM12878_merge`, and `GM12878` cell-type names. In all four shell commands, set `--out {OUTPUT_ROOT}` and keep the current prediction parameters.

- [ ] **Step 4: Replace Plan E inputs, outputs, and broken merge references**

Use:

```python
model = str(SRC / "models" / "standard" / "epoch=78-step=47004.ckpt")
bulk_seq = str(CORIGAMI_DATA / "hg38" / "dna_sequence")
bulk_ctcf = str(CORIGAMI_DATA / "hg38" / "gm12878" / "genomic_features" / "ctcf_log2fc.bw")
seq_pat = str(CORIGAMI_DATA / "hg38" / "dna_sequence_diploid" / "paternal")
seq_mat = str(CORIGAMI_DATA / "hg38" / "dna_sequence_diploid" / "maternal")
ctcf_pat = str(CORIGAMI_DATA / "hg38" / "gm12878" / "genomic_features" / "plan-e" / "ctcf_log2fc_cont_paternal.bw")
ctcf_mat = str(CORIGAMI_DATA / "hg38" / "gm12878" / "genomic_features" / "plan-e" / "ctcf_log2fc_cont_maternal.bw")
atac_pat = str(DSC_ATAC / "GM12878_dscNanoATAC_paternal.bw")
atac_mat = str(DSC_ATAC / "GM12878_dscNanoATAC_maternal.bw")
merge_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_merged.bw")
region_list = str(REGION_LIST)
chrom_sizes = str(CHROM_SIZES)
```

Change `merge_pred.input` to:

```python
        model = model,
        seq   = bulk_seq,
        ctcf  = bulk_ctcf,
        atac  = merge_atac,
```

Put all three outputs under `OUTPUT_ROOT`, retain current cell-type names, and pass `--out {OUTPUT_ROOT}`.

- [ ] **Step 5: Replace Plan H inputs and outputs**

Use:

```python
model = str(SRC / "models" / "atac-only" / "epoch=46-step=55929.ckpt")
inference_script = str(SRC / "prediction" / "predict_atac_only.py")
pat_seq = str(CORIGAMI_DATA / "hg38" / "dna_sequence_diploid" / "paternal")
mat_seq = str(CORIGAMI_DATA / "hg38" / "dna_sequence_diploid" / "maternal")
bulk_seq = str(CORIGAMI_DATA / "hg38" / "dna_sequence")
pat_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_paternal.bw")
mat_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_maternal.bw")
bulk_atac = str(CORIGAMI_DATA / "hg38" / "gm12878" / "genomic_features" / "atac.bw")
merge_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_merged.bw")
region_list = str(REGION_LIST)
chrom_sizes = str(CHROM_SIZES)
```

Put all four outputs under `OUTPUT_ROOT` and pass `--out {OUTPUT_ROOT}` to `predict_atac_only.py`.

- [ ] **Step 6: Install the two small shared inputs, verify rule parsing, and commit**

Copy the real region and chromosome files to the final paths required by all three Snakefiles, then run:

```bash
mkdir -p src/data/regions src/data/reference
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/GM12878_2M_10k_snp_density_summary.txt src/data/regions/
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GRCh38_ref/GRCh38.chrom.sizes src/data/reference/
python -m unittest tests.test_repository_contract -v
snakemake --snakefile src/prediction/run_top_pred.smk --config TOP_N=0 --dry-run
snakemake --snakefile src/prediction/run_top_pred_planE.smk --config TOP_N=0 --dry-run
snakemake --snakefile src/prediction/run_top_pred_planH.smk --config TOP_N=0 --dry-run
git add src/prediction tests/test_repository_contract.py
git commit -m "refactor: use repository paths for prediction"
```

Expected: tests pass; each dry-run parses the Snakefile and reports no prediction jobs for `TOP_N=0`. If Snakemake checks missing top-level region files before rule expansion, use copies of the real small region/chromosome files in their final locations, which Task 6 will retain.

---

### Task 4: Parameterize diploid DNA and Plan E CTCF generation

**Files:**
- Modify: `src/generation/diploid-dna/01_build_haplotype_fasta.sh`
- Modify: `src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py`
- Create: `src/generation/README.md`
- Modify: `tests/test_repository_contract.py`

**Interfaces:**
- Consumes: uploaded Platinum Genomes VCF, Zenodo bulk DNA/CTCF, and checked-in chromosome sizes/PWM
- Produces: ignored `dna_sequence_diploid/{paternal,maternal}` and `genomic_features/plan-e/*.bw`

- [ ] **Step 1: Add failing generation-default tests**

Add:

```python
    def test_generation_tools_default_to_repository_assets(self):
        diploid = (ROOT / "src/generation/diploid-dna/01_build_haplotype_fasta.sh").read_text()
        ctcf = (ROOT / "src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py").read_text()
        self.assertIn('REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"', diploid)
        self.assertIn("src/data/variants/illumina_PlatinumGenomes", diploid)
        self.assertIn("dna_sequence_diploid", diploid)
        self.assertIn("default_paths", ctcf)
        self.assertIn("src/data/variants/illumina_PlatinumGenomes", ctcf)
        self.assertNotIn("/gpfs1/", diploid)
```

Run the test; expect failure.

- [ ] **Step 2: Give the haplotype script positional overrides and repository defaults**

Replace the editable constants with:

```bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
DATA_ROOT="${REPO_ROOT}/src/data/corigami_data/data"

REF="${1:-${DATA_ROOT}/hg38/dna_sequence/hg38.fa}"
VCF="${2:-${REPO_ROOT}/src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz}"
OUT="${3:-${DATA_ROOT}/hg38/dna_sequence_diploid}"
SAMPLE="${SAMPLE:-NA12878}"
THREADS="${THREADS:-4}"
```

Quote every variable expansion used as a path, leave SNP-only filtering and the `1pIu`/`2pIu` consensus behavior unchanged, and add this usage block near the top:

```text
Usage: bash 01_build_haplotype_fasta.sh [reference.fa] [phased.vcf.gz] [output_dir]
```

- [ ] **Step 3: Add repository-derived defaults to the Plan E Python CLI**

Add:

```python
from pathlib import Path


def default_paths():
    repo_root = Path(__file__).resolve().parents[3]
    data_root = repo_root / "src" / "data"
    corigami = data_root / "corigami_data" / "data"
    return {
        "meme": Path(__file__).with_name("MA0139.1.meme"),
        "vcf": data_root / "variants" / "illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz",
        "ref_fasta": corigami / "hg38" / "dna_sequence" / "hg38.fa",
        "bulk_ctcf": corigami / "hg38" / "gm12878" / "genomic_features" / "ctcf_log2fc.bw",
        "chrom_sizes": data_root / "reference" / "GRCh38.chrom.sizes",
        "out_dir": corigami / "hg38" / "gm12878" / "genomic_features" / "plan-e",
    }
```

In `parse_args()`, call `defaults = default_paths()` and replace the six `required=True` declarations with `default=str(defaults[...])`; preserve every existing option name and algorithm.

- [ ] **Step 4: Document exact generation commands**

Create `src/generation/README.md` with commands:

````markdown
# Generated allele-specific inputs

From the repository root, after extracting the Zenodo data and installing the dependencies listed in `docs/dependencies.md`:

```bash
bash src/generation/diploid-dna/01_build_haplotype_fasta.sh
python src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py
```

The first command creates paternal and maternal FASTA directories plus a rebuildable SNP-only VCF under `src/data/corigami_data/data/hg38/dna_sequence_diploid/`. The second creates paternal and maternal continuous-PWM CTCF BigWigs under `src/data/corigami_data/data/hg38/gm12878/genomic_features/plan-e/`. These outputs are intentionally not committed.
````

- [ ] **Step 5: Verify syntax, CLI defaults, tests, and commit**

Run:

```bash
bash -n src/generation/diploid-dna/01_build_haplotype_fasta.sh
python -m py_compile src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py
python src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py --help
python -m unittest tests.test_repository_contract -v
git add src/generation tests/test_repository_contract.py
git commit -m "feat: make allele-specific inputs reproducible"
```

Expected: syntax and tests pass; `--help` lists defaults without opening the large inputs.

---

### Task 5: Rewrite notebook paths while preserving outputs

**Files:**
- Create: `tools/update_notebook_paths.py`
- Modify: `snp-density/SNP_density.ipynb`
- Modify: `benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb`
- Modify: `benchmarks/corigami_predict_benchmark_planAEH.ipynb`
- Modify: `tests/test_repository_contract.py`

**Interfaces:**
- Consumes: notebook JSON and a repository root derived from each notebook location
- Produces: repository-local VCF/chromosome/region/prediction paths with all historical `outputs` objects unchanged

- [ ] **Step 1: Add failing notebook source-path tests**

Add:

```python
    def test_notebook_sources_use_repository_prediction_layout(self):
        for relative in (
            "benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb",
            "benchmarks/corigami_predict_benchmark_planAEH.ipynb",
        ):
            notebook = json.loads((ROOT / relative).read_text())
            sources = "\n".join(
                "".join(cell.get("source", []))
                if isinstance(cell.get("source", []), list)
                else cell.get("source", "")
                for cell in notebook["cells"]
            )
            self.assertIn("outputs/prediction/plan-a", sources)
        plan_aeh = json.loads((ROOT / "benchmarks/corigami_predict_benchmark_planAEH.ipynb").read_text())
        sources = json.dumps([cell.get("source") for cell in plan_aeh["cells"]])
        self.assertIn("outputs/prediction/plan-e", sources)
        self.assertIn("outputs/prediction/plan-h", sources)

    def test_snp_notebook_uses_uploaded_vcf_and_chrom_sizes(self):
        notebook = json.loads((ROOT / "snp-density/SNP_density.ipynb").read_text())
        sources = json.dumps([cell.get("source") for cell in notebook["cells"]])
        self.assertIn("src/data/variants/illumina_PlatinumGenomes", sources)
        self.assertIn("src/data/reference/GRCh38.chrom.sizes", sources)
        self.assertIn("tileGenome", sources)
```

Run these tests; expect failure while the output-hash test continues to pass.

- [ ] **Step 2: Implement a structured notebook rewriter with an output guard**

Create `tools/update_notebook_paths.py` that:

```python
#!/usr/bin/env python3
import copy
import json
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


REPLACEMENTS = {
    "benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb": {
        "/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/predict/": "../outputs/prediction/plan-a/",
        "/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/GM12878_2M_10k_snp_density_summary.txt": "../src/data/regions/GM12878_2M_10k_snp_density_summary.txt",
    },
    "benchmarks/corigami_predict_benchmark_planAEH.ipynb": {
        "/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/predict/": "../outputs/prediction/plan-a/",
        "/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/predict_planE/": "../outputs/prediction/plan-e/",
        "/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/predict_atac_model/": "../outputs/prediction/plan-h/",
        "/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/GM12878_2M_10k_snp_density_summary.txt": "../src/data/regions/GM12878_2M_10k_snp_density_summary.txt",
    },
}


def replace_source(source, replacements):
    is_list = isinstance(source, list)
    text = "".join(source) if is_list else source
    for old, new in replacements.items():
        text = text.replace(old, new)
    return text.splitlines(keepends=True) if is_list else text


def rewrite(relative, replacements):
    path = ROOT / relative
    notebook = json.loads(path.read_text())
    outputs = copy.deepcopy([
        cell.get("outputs") for cell in notebook["cells"] if cell.get("cell_type") == "code"
    ])
    for cell in notebook["cells"]:
        cell["source"] = replace_source(cell.get("source", []), replacements)
    after = [cell.get("outputs") for cell in notebook["cells"] if cell.get("cell_type") == "code"]
    if outputs != after:
        raise RuntimeError(f"notebook outputs changed: {relative}")
    path.write_text(json.dumps(notebook, ensure_ascii=False, indent=1) + "\n")


for relative, replacements in REPLACEMENTS.items():
    rewrite(relative, replacements)
```

- [ ] **Step 3: Extend the rewriter for SNP-density inputs and in-notebook tiling**

Add the SNP notebook to `REPLACEMENTS` so cell 0 gains `library(GenomicRanges)`, then replace code-cell sources 2, 13, 14, 28, and 39 by index. Add this configuration to the Python rewriter:

```python
REPLACEMENTS["snp-density/SNP_density.ipynb"] = {
    "library(patchwork)\n": "library(patchwork)\nlibrary(GenomicRanges)\n",
}

SNP_CELL_SOURCES = {
    2: '''# Use repository-local phased variants and reference metadata.
repo_root <- normalizePath("..")
vcf_path <- file.path(repo_root, "src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz")
chrom_sizes_path <- file.path(repo_root, "src/data/reference/GRCh38.chrom.sizes")
summary_path <- file.path(repo_root, "src/data/regions/GM12878_2M_10k_snp_density_summary.txt")
snp <- read.table(vcf_path)
''',
    13: '''# Build 10 kb GRCh38 tiles directly from the uploaded chromosome sizes.
chrom_sizes <- read.table(chrom_sizes_path, col.names = c("chrom", "length"))
seqinfo_hg38 <- Seqinfo(
  seqnames = chrom_sizes$chrom,
  seqlengths = chrom_sizes$length
)
windows_10k <- tileGenome(
  seqinfo_hg38,
  tilewidth = 10000,
  cut.last.tile.in.chrom = TRUE
)
bins <- as.data.frame(windows_10k)[, c("seqnames", "start", "end")]
colnames(bins) <- c("chrom", "start", "end")
bins$start <- bins$start - 1L
bins$idx <- seq_len(nrow(bins))
''',
    14: '''# Convert the generated 10 kb table to the GRanges layout used below.
bins_gr <- dt2gr(bins)
''',
    28: '''# Build 500 kb tiles and retain chr1-22 plus chrX.
windows_500k <- tileGenome(
  seqinfo_hg38,
  tilewidth = 500000,
  cut.last.tile.in.chrom = TRUE
)
bins_500k <- as.data.frame(windows_500k)[, c("seqnames", "start", "end")]
colnames(bins_500k) <- c("chrom", "start", "end")
bins_500k$start <- bins_500k$start - 1L
bins_500k <- bins_500k[bins_500k$chrom %in% paste0("chr", c(1:22, "X")), ]
bins_500k$chrom <- factor(bins_500k$chrom, levels = paste0("chr", c(1:22, "X")))
bins_500k <- bins_500k %>% arrange(chrom, start)
bins_500k$idx <- seq_len(nrow(bins_500k))
bins_500k_gr <- dt2gr(bins_500k)
''',
    39: '''# Write the ranked 2 Mb SNP-density regions to the shared repository input.
write.table(snp_sum_sw, summary_path,
            row.names = F, quote = F, sep = "\\t")
''',
}
```

Change `rewrite` to accept `cell_sources=None`. After applying text replacements, assign each configured cell with `notebook["cells"][index]["source"] = text.splitlines(keepends=True)`, and call it with `SNP_CELL_SOURCES` only for `snp-density/SNP_density.ipynb`. Keep every other cell, including the heterozygous-SNV filters, aggregation calculations, plots, and output objects unchanged.

- [ ] **Step 4: Run the rewriter and all notebook guards**

Run:

```bash
python tools/update_notebook_paths.py
python -m json.tool snp-density/SNP_density.ipynb >/dev/null
python -m json.tool benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb >/dev/null
python -m json.tool benchmarks/corigami_predict_benchmark_planAEH.ipynb >/dev/null
python -m unittest tests.test_repository_contract -v
```

Expected: JSON parsing and all tests pass, including the three original output hashes.

- [ ] **Step 5: Review source-only notebook diffs and commit**

Run:

```bash
git diff --word-diff=plain -- snp-density/SNP_density.ipynb benchmarks/
git add tools snp-density benchmarks tests/test_repository_contract.py
git commit -m "refactor: use repository paths in analysis notebooks"
```

Expected: changes are limited to `source` fields and JSON serialization; `outputs` content is unchanged.

---

### Task 6: Configure Git LFS and import selected data assets

**Files:**
- Create: `.gitattributes`
- Modify: `.gitignore`
- Create via Git LFS: `src/models/standard/epoch=78-step=47004.ckpt`
- Create via Git LFS: `src/models/atac-only/epoch=46-step=55929.ckpt`
- Create via Git LFS: `src/data/dscNanoATAC/GM12878_dscNanoATAC_paternal.bw`
- Create via Git LFS: `src/data/dscNanoATAC/GM12878_dscNanoATAC_maternal.bw`
- Create via Git LFS: `src/data/dscNanoATAC/GM12878_dscNanoATAC_merged.bw`
- Create via Git LFS: `src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz`
- Create via Git LFS: `src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz.tbi`
- Create: `src/data/regions/GM12878_2M_10k_snp_density_summary.txt`
- Create: `src/data/reference/GRCh38.chrom.sizes`
- Modify: `tests/test_repository_contract.py`

**Interfaces:**
- Consumes: the nine confirmed cluster source paths and their approved SHA-256 values
- Produces: repository assets at the exact paths consumed by Tasks 2-5, with large files represented as LFS pointers in Git

- [ ] **Step 1: Add failing data-presence and hash tests**

Add a class-level mapping and test:

```python
    ASSET_HASHES = {
        "src/models/standard/epoch=78-step=47004.ckpt": "81c1379928adfbe0ec26f236a03347bf51a3ccecf1a261ef343f04f9e2fa0c55",
        "src/models/atac-only/epoch=46-step=55929.ckpt": "d41c9ee236eeaeeaeb7bd49a516bcedb07620d830756068ecc7b83949892e599",
        "src/data/dscNanoATAC/GM12878_dscNanoATAC_paternal.bw": "6c8a0249e6b3097a0a0e6b5a0035cccb555a0a08c0622fb70140d8e010b21b52",
        "src/data/dscNanoATAC/GM12878_dscNanoATAC_maternal.bw": "4e7304569a43eea50c3c556cc201f4eced93e2eb7a14bc523c704ff8347ddd6a",
        "src/data/dscNanoATAC/GM12878_dscNanoATAC_merged.bw": "36cea84aeea3fb6d414534ef8363a8f2bcbe9fcbae329d2a331968a95a7938a9",
        "src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz": "de6169dffe3d758fe8854fc36dc30c11e73f922c1fd809341f4aaf4a44a22fb7",
        "src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz.tbi": "01c66ac39725a9e0196468244e34f3a8188dc65f37353290c535bfd015d84625",
        "src/data/regions/GM12878_2M_10k_snp_density_summary.txt": "4820a69d48451a21bbf2c87e480a125e30b127e5f7e15fd3e9043c80570570fc",
        "src/data/reference/GRCh38.chrom.sizes": "d525ee20551f34768f4017c7a779a3f3c7b947dacdea27838a5776508834b306",
    }

    def test_imported_assets_match_approved_hashes(self):
        for relative, expected in self.ASSET_HASHES.items():
            path = ROOT / relative
            self.assertTrue(path.is_file(), relative)
            actual = hashlib.sha256(path.read_bytes()).hexdigest()
            self.assertEqual(expected, actual, relative)
```

Run this test; expect nine missing-file failures.

- [ ] **Step 2: Install Git LFS in the user account and initialize it locally**

Run:

```bash
mkdir -p "$HOME/.local/bin" /tmp/as-c-origami-git-lfs
gh release download --repo git-lfs/git-lfs --pattern 'git-lfs-linux-amd64-v*.tar.gz' --dir /tmp/as-c-origami-git-lfs
tar -xzf /tmp/as-c-origami-git-lfs/git-lfs-linux-amd64-v*.tar.gz -C /tmp/as-c-origami-git-lfs
install -m 755 /tmp/as-c-origami-git-lfs/git-lfs-*/git-lfs "$HOME/.local/bin/git-lfs"
export PATH="$HOME/.local/bin:$PATH"
git lfs install --local
git lfs version
```

Expected: `git-lfs/` version output and a local filter configuration; no root access required.

- [ ] **Step 3: Configure LFS patterns before importing binaries**

Run:

```bash
git lfs track 'src/models/**/*.ckpt'
git lfs track 'src/data/**/*.bw'
git lfs track 'src/data/variants/*.vcf.gz'
git lfs track 'src/data/variants/*.vcf.gz.tbi'
```

Update `.gitignore` so it contains:

```gitignore
outputs/
.snakemake/
.ipynb_checkpoints/
__pycache__/
*.py[cod]
*.log
src/data/corigami_data/data/**
!src/data/corigami_data/README.md
```

Remove the old global `*.ckpt` and `*.bw` ignore rules so intended LFS files can be added. Keep generated `.npy`, R workspace, FASTA, bedGraph, and temporary-analysis exclusions.

- [ ] **Step 4: Copy assets into their final paths and verify all hashes**

Run:

```bash
mkdir -p src/models/standard src/models/atac-only src/data/dscNanoATAC src/data/variants src/data/regions src/data/reference
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/GM12878/models/epoch=78-step=47004.ckpt src/models/standard/
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/software/corigami/GM12878_ATAC_ONLY/models/epoch=46-step=55929.ckpt src/models/atac-only/
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/Results/GM12878_merged_paternal_fragments_slop_sort_deeptools.bw src/data/dscNanoATAC/GM12878_dscNanoATAC_paternal.bw
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/Results/GM12878_merged_maternal_fragments_slop_sort_deeptools.bw src/data/dscNanoATAC/GM12878_dscNanoATAC_maternal.bw
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/GM12878_merged_slop_sort_deeptools.bw src/data/dscNanoATAC/GM12878_dscNanoATAC_merged.bw
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz src/data/variants/
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz.tbi src/data/variants/
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/GM12878_2M_10k_snp_density_summary.txt src/data/regions/
cp /gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GRCh38_ref/GRCh38.chrom.sizes src/data/reference/
python -m unittest tests.test_repository_contract.RepositoryContractTest.test_imported_assets_match_approved_hashes -v
```

Expected: all nine hash comparisons pass. A mismatch stops the import before `git add`.

- [ ] **Step 5: Confirm LFS staging and commit data assets**

Run:

```bash
git add .gitattributes .gitignore src/models src/data tests/test_repository_contract.py
git lfs status
git lfs ls-files --all
git diff --cached --check
for path in \
  'src/models/standard/epoch=78-step=47004.ckpt' \
  'src/models/atac-only/epoch=46-step=55929.ckpt' \
  'src/data/dscNanoATAC/GM12878_dscNanoATAC_paternal.bw' \
  'src/data/dscNanoATAC/GM12878_dscNanoATAC_maternal.bw' \
  'src/data/dscNanoATAC/GM12878_dscNanoATAC_merged.bw' \
  'src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz' \
  'src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz.tbi'; do
  git show ":$path" | head -n 1 | grep -Fx 'version https://git-lfs.github.com/spec/v1'
done
git commit -m "data: add GM12878 workflow assets with Git LFS"
```

Expected: all seven large tracked files are LFS pointers; the region and chromosome files are normal Git blobs.

---

### Task 7: Update provenance and usage documentation

**Files:**
- Modify: `README.md`
- Modify: `docs/workflow.md`
- Modify: `docs/dependencies.md`
- Modify: `docs/source-manifest.tsv`

**Interfaces:**
- Consumes: final repository layout, public source URLs, source hashes, and repository-version hashes
- Produces: a reproducible user guide and auditable provenance table

- [ ] **Step 1: Expand the manifest schema and populate every imported artifact**

Use this header:

```tsv
category	repository_path	source_path	public_source	purpose	source_sha256	repository_sha256
```

Retain the original source path and source hash for each archived workflow, add the five imported helper files, and add all nine imported assets. Use the Zenodo URL for bulk-data documentation, the Platinum Genomes URL for VCF/index rows, and `local GM12878 dscNanoATAC processing output` for the three BigWig public-source fields. Compute `repository_sha256` from the final checked-out file; unchanged binaries must have identical source and repository hashes.

Verify with:

```bash
python - <<'PY'
import csv, hashlib
from pathlib import Path

with Path('docs/source-manifest.tsv').open(newline='') as handle:
    for row in csv.DictReader(handle, delimiter='\t'):
        actual = hashlib.sha256(Path(row['repository_path']).read_bytes()).hexdigest()
        assert actual == row['repository_sha256'], row['repository_path']
PY
```

Expected: exit 0 with no output.

- [ ] **Step 2: Rewrite README around uploaded, downloaded, and generated assets**

Document:

- `src/training`, `src/prediction`, and `src/generation` entry points.
- The two uploaded checkpoints, three explicitly GM12878 dscNanoATAC tracks, VCF/index, region summary, and chromosome sizes.
- The exact Zenodo download and extraction commands below; verify the API-published MD5 before extraction:

```bash
curl -L 'https://zenodo.org/record/7226561/files/corigami_data_gm12878_add_on.tar.gz?download=1' \
  -o corigami_data_gm12878_add_on.tar.gz
echo '8a5981d9ba167bfa1a4f308c3ddff4cc  corigami_data_gm12878_add_on.tar.gz' | md5sum -c -
mkdir -p src/data/corigami_data
tar -xzf corigami_data_gm12878_add_on.tar.gz -C src/data/corigami_data
test -d src/data/corigami_data/data/hg38/dna_sequence
test -d src/data/corigami_data/data/hg38/gm12878
```
- Platinum Genomes as the VCF source.
- Commands from `src/generation/README.md` for diploid DNA and Plan E CTCF.
- `snakemake --snakefile src/prediction/<name> --config TOP_N=<n>` examples and output locations.
- A warning that full training/prediction needs the documented conda/GPU environment and omitted Zenodo data.

- [ ] **Step 3: Update workflow and dependency docs**

In `docs/workflow.md`, replace legacy directory references with the final `src/` and `outputs/` paths and show that one phased VCF feeds both SNP density and diploid DNA generation. In `docs/dependencies.md`, separate software requirements for training/prediction, diploid FASTA generation, Plan E CTCF generation, and notebook analysis; list Dip3D/blacklist/reference matrices as external benchmark inputs.

- [ ] **Step 4: Check docs, links, provenance, and commit**

Run:

```bash
rg -n 'training/|prediction/' README.md docs | head -100
rg -n 'Zenodo|PlatinumGenomes|GM12878_dscNanoATAC' README.md docs
python -m unittest tests.test_repository_contract -v
git diff --check
git add README.md docs
git commit -m "docs: document local assets and data provenance"
```

Expected: all paths describe the final layout; public sources and GM12878 naming are explicit.

---

### Task 8: Perform end-to-end verification and publish

**Files:**
- Modify only if a verification defect is found: the file responsible for that defect

**Interfaces:**
- Consumes: complete local repository and configured private GitHub remote
- Produces: verified private `origin/main` with all normal Git and LFS objects uploaded

- [ ] **Step 1: Run syntax and repository contract verification**

Run:

```bash
bash -n src/training/corigami_train.sh
bash -n src/training/corigami_train_atac_only.sh
bash -n src/generation/diploid-dna/01_build_haplotype_fasta.sh
python -m py_compile src/training/train_atac_only.py src/prediction/predict_atac_only.py src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py
python -m unittest tests.test_repository_contract -v
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 2: Run all three zero-region Snakemake dry-runs**

Run:

```bash
snakemake --snakefile src/prediction/run_top_pred.smk --config TOP_N=0 --dry-run
snakemake --snakefile src/prediction/run_top_pred_planE.smk --config TOP_N=0 --dry-run
snakemake --snakefile src/prediction/run_top_pred_planH.smk --config TOP_N=0 --dry-run
```

Expected: all Snakefiles parse, read local region/chromosome files, and resolve outputs without launching GPU jobs.

- [ ] **Step 3: Audit paths, notebook outputs, LFS pointers, and Git blob sizes**

Run:

```bash
! rg -n '/gpfs1/|/home/' src --glob '*.sh' --glob '*.py' --glob '*.smk'
python -m unittest tests.test_repository_contract.RepositoryContractTest.test_notebook_outputs_are_unchanged -v
git lfs fsck
git lfs ls-files --all
git rev-list --objects --all | git cat-file --batch-check='%(objecttype) %(objectname) %(objectsize) %(rest)' | awk '$1 == "blob" && $3 > 100000000 {print; bad=1} END {exit bad}'
```

Expected: no executable source contains old absolute paths, notebook outputs match all baselines, LFS is healthy, and no normal Git blob exceeds 100 MB.

- [ ] **Step 4: Scan tracked content for accidental credentials**

Scan all tracked content first and review every match:

```bash
git grep -nEI 'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|(password|passwd|secret|token)[[:space:]]*[:=][[:space:]]*[^[:space:]#]+' -- . || true
```

The approved design and plan can match their own scan examples. After reviewing those hits, rerun the same scan with only those two documentation trees excluded:

```bash
! git grep -nEI 'gh[pousr]_[A-Za-z0-9]{20,}|github_pat_[A-Za-z0-9_]{20,}|AKIA[0-9A-Z]{16}|-----BEGIN [A-Z0-9 ]*PRIVATE KEY-----|(password|passwd|secret|token)[[:space:]]*[:=][[:space:]]*[^[:space:]#]+' -- . ':(exclude)docs/superpowers/specs/*' ':(exclude)docs/superpowers/plans/*'
```

Expected: no live credential material and the second command exits 0 with no output.

- [ ] **Step 5: Confirm private remote metadata and push normal/LFS objects**

Run:

```bash
test "$(gh repo view LuJiansen/AS-C.Origami --json visibility --jq .visibility)" = PRIVATE
test "$(git remote get-url origin)" = 'https://github.com/LuJiansen/AS-C.Origami.git'
git status --short --branch
git push origin main
git lfs push --all origin main
```

Expected: visibility is `PRIVATE`, the remote is exact, and both Git and LFS pushes complete without force.

- [ ] **Step 6: Verify remote synchronization and final inventory**

Run:

```bash
git fetch origin main
test "$(git rev-parse main)" = "$(git rev-parse origin/main)"
git status --porcelain
gh repo view LuJiansen/AS-C.Origami --json nameWithOwner,visibility,url
git lfs ls-files --all
```

Expected: local and remote `main` match, the worktree is clean, GitHub reports `LuJiansen/AS-C.Origami` as private, and all seven intended LFS files are listed.
