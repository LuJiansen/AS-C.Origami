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


if __name__ == "__main__":
    unittest.main()
