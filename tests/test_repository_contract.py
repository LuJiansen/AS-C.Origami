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

    def test_generation_tools_default_to_repository_assets(self):
        diploid = (ROOT / "src/generation/diploid-dna/01_build_haplotype_fasta.sh").read_text()
        ctcf = (ROOT / "src/generation/plan-e-ctcf/06_continuous_pwm_ctcf.py").read_text()
        self.assertIn('REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"', diploid)
        self.assertIn("src/data/variants/illumina_PlatinumGenomes", diploid)
        self.assertIn("dna_sequence_diploid", diploid)
        self.assertIn("default_paths", ctcf)
        self.assertIn("src/data/variants/illumina_PlatinumGenomes", ctcf)
        self.assertNotIn("/gpfs1/", diploid)

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


if __name__ == "__main__":
    unittest.main()
