# Plan A: bulk-DNA bulk-CTCF + allele-specific ATAC C.Origami prediction.
# Compared against plan B (fully allele-specific) using the same region set
# and the same filename convention, so the two registries intersect 1-to-1
# in the benchmark notebook.
#
# Inputs per haplotype:
#   --seq  : bulk hg38 (no diploid consensus)              - same for pat / mat
#   --ctcf : bulk GM12878 CTCF log2(IP/input)              - same for pat / mat
#   --atac : haplotype-specific 10X ATAC (paternal/maternal)
# 'all_pred' uses the bulk ATAC for the merged-haplotype reference.
#
# ── Filename / region convention ─────────────────────────────────────────────
# Region keys (and therefore filenames) are
#     <chr>_<predict_start>.npy
# where
#     predict_start = (snp_density file 'start' column)        [WIN_OFFSET = 0]
# corigami-predict is invoked with --chr <chr> --start <predict_start>, so its
# 2,097,152-bp prediction window covers
#     [predict_start, predict_start + 2_097_152)
# Concretely, for a SNP-density row "chr4  150500000  152500000  50.00":
#     predict_start = 150500000
#     filename      = chr4_150500000.npy
#     prediction    = chr4:150,500,000 - 152,597,152  (2,097,152 bp)
#     SNP-dense win = chr4:150,500,000 - 152,500,000  (2,000,000 bp)
# The prediction window fully contains the SNP-dense window plus a small
# (~97 kb) overhang on the right edge. Plan A and plan B use the *same*
# region list with WIN_OFFSET = 0, so a given filename refers to byte-identical
# genomic coordinates in both directories — fair comparison.
# ─────────────────────────────────────────────────────────────────────────────

from pathlib import Path

############################ inputs ############################
REPO_ROOT = Path(workflow.snakefile).resolve().parents[2]
SRC = REPO_ROOT / "src"
DATA = SRC / "data"
CORIGAMI_DATA = DATA / "corigami_data" / "data"
REGION_LIST = DATA / "regions" / "GM12878_2M_10k_snp_density_summary.txt"
CHROM_SIZES = DATA / "reference" / "GRCh38.chrom.sizes"
DSC_ATAC = DATA / "dscNanoATAC"
OUTPUT_ROOT = REPO_ROOT / "outputs/prediction/plan-a"

model = str(SRC / "models" / "standard" / "epoch=78-step=47004.ckpt")

# Plan A: bulk seq + bulk CTCF, only ATAC is allele-specific
seq = str(CORIGAMI_DATA / "hg38" / "dna_sequence")
ctcf = str(CORIGAMI_DATA / "hg38" / "gm12878" / "genomic_features" / "ctcf_log2fc.bw")
atac = str(CORIGAMI_DATA / "hg38" / "gm12878" / "genomic_features" / "atac.bw")
pat_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_paternal.bw")
mat_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_maternal.bw")
merge_atac = str(DSC_ATAC / "GM12878_dscNanoATAC_merged.bw")

region_list = str(REGION_LIST)
chrom_sizes = str(CHROM_SIZES)
TOP_N       = int(config.get("TOP_N", 5000))   # override at the cli with: --config TOP_N=50
WIN_OFFSET  = 0                                 # 0 → predict_start aligns with snp_density 'start'
WIN_SIZE    = 2_097_152                         # corigami input window length (2^21 bp)

############################ chromosome sizes ############################
chrom_size_map = {}
with open(chrom_sizes) as f:
    for line in f:
        c, s = line.strip().split()[:2]
        chrom_size_map[c] = int(s)

############################ region list ############################
regions = []
with open(region_list) as f:
    next(f)  # skip header
    for line in f:
        fields = line.strip().split()
        if len(fields) < 2:
            continue
        chrom = fields[0]
        start = int(fields[1]) - WIN_OFFSET
        if start < 0:
            continue
        # Drop windows that extend past the chromosome end — corigami-predict
        # raises "Invalid interval bounds!" when bigwig.values() is queried
        # past the chrom end. With WIN_OFFSET = 0 this happens on chr-end-
        # adjacent SNP-dense rows (e.g. chr18:78500000 + 2.097Mb > 80.37Mb).
        if chrom in chrom_size_map and start + WIN_SIZE > chrom_size_map[chrom]:
            continue
        regions.append(f"{chrom}_{start}")
regions = regions[:TOP_N]
print(f"[planA] predicting {len(regions)} regions (top {TOP_N})")

############################ rules ############################
rule all:
    input:
        expand(str(OUTPUT_ROOT / "GM12878_pat/prediction/npy/{region}.npy"), region=regions),
        expand(str(OUTPUT_ROOT / "GM12878_mat/prediction/npy/{region}.npy"), region=regions),
        expand(str(OUTPUT_ROOT / "GM12878_merge/prediction/npy/{region}.npy"), region=regions),
        expand(str(OUTPUT_ROOT / "GM12878/prediction/npy/{region}.npy"), region=regions),

rule pat_pred:
    input:
        model = model,
        seq   = seq,
        ctcf  = ctcf,
        atac  = pat_atac,
    output:
        str(OUTPUT_ROOT / "GM12878_pat/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        # SLURM (--gres=gpu:1) sets CUDA_VISIBLE_DEVICES automatically;
        # do NOT override it here.
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out {OUTPUT_ROOT} \\
            --celltype GM12878_pat \\
            --chr $chr --start $start \\
            --model {input.model} \\
            --seq {input.seq} \\
            --ctcf {input.ctcf} \\
            --atac {input.atac}
        set +u; conda deactivate; set -u
        # Force GPFS attribute-cache refresh so snakemake's subsequent stat() sees
        # the file that corigami-predict just wrote — otherwise --latency-wait
        # times out with MissingOutputException despite the .npy being on disk.
        ls -l {output} >/dev/null
    """

rule mat_pred:
    input:
        model = model,
        seq   = seq,
        ctcf  = ctcf,
        atac  = mat_atac,
    output:
        str(OUTPUT_ROOT / "GM12878_mat/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out {OUTPUT_ROOT} \\
            --celltype GM12878_mat \\
            --chr $chr --start $start \\
            --model {input.model} \\
            --seq {input.seq} \\
            --ctcf {input.ctcf} \\
            --atac {input.atac}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """

rule merge_pred:
    input:
        model = model,
        seq   = seq,
        ctcf  = ctcf,
        atac  = merge_atac,
    output:
        str(OUTPUT_ROOT / "GM12878_merge/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out {OUTPUT_ROOT} \\
            --celltype GM12878_merge \\
            --chr $chr --start $start \\
            --model {input.model} \\
            --seq {input.seq} \\
            --ctcf {input.ctcf} \\
            --atac {input.atac}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """

rule all_pred:
    input:
        model = model,
        seq   = seq,
        ctcf  = ctcf,
        atac  = atac,
    output:
        str(OUTPUT_ROOT / "GM12878/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out {OUTPUT_ROOT} \\
            --celltype GM12878 \\
            --chr $chr --start $start \\
            --model {input.model} \\
            --seq {input.seq} \\
            --ctcf {input.ctcf} \\
            --atac {input.atac}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """
