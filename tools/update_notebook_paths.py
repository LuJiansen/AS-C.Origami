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
    "snp-density/SNP_density.ipynb": {
        "library(patchwork)\n": "library(patchwork)\nlibrary(GenomicRanges)\n",
    },
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


def replace_source(source, replacements):
    is_list = isinstance(source, list)
    text = "".join(source) if is_list else source
    for old, new in replacements.items():
        if old == "library(patchwork)\n" and "library(GenomicRanges)\n" in text:
            continue
        text = text.replace(old, new)
    return text.splitlines(keepends=True) if is_list else text


def rewrite(relative, replacements, cell_sources=None):
    path = ROOT / relative
    notebook = json.loads(path.read_text())
    outputs = copy.deepcopy([
        cell.get("outputs") for cell in notebook["cells"] if cell.get("cell_type") == "code"
    ])
    for cell in notebook["cells"]:
        cell["source"] = replace_source(cell.get("source", []), replacements)
    for index, source in (cell_sources or {}).items():
        notebook["cells"][index]["source"] = source.splitlines(keepends=True)
    after = [
        cell.get("outputs")
        for cell in notebook["cells"]
        if cell.get("cell_type") == "code"
    ]
    if outputs != after:
        raise RuntimeError(f"notebook outputs changed: {relative}")
    path.write_text(json.dumps(notebook, ensure_ascii=False, indent=1) + "\n")


for relative, replacements in REPLACEMENTS.items():
    cell_sources = SNP_CELL_SOURCES if relative == "snp-density/SNP_density.ipynb" else None
    rewrite(relative, replacements, cell_sources)
