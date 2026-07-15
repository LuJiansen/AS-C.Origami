import csv
import hashlib
import json
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]


class RepositoryContractTest(unittest.TestCase):
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
