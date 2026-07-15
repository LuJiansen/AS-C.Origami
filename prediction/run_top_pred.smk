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

import os

############################ inputs ############################
model = 'GM12878/models/epoch=78-step=47004.ckpt'

# Plan A: bulk seq + bulk CTCF, only ATAC is allele-specific
seq      = 'corigami_data/data/hg38/dna_sequence'
ctcf     = 'corigami_data/data/hg38/gm12878/genomic_features/ctcf_log2fc.bw'
atac     = 'corigami_data/data/hg38/gm12878/genomic_features/atac.bw'
pat_atac = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/Results/GM12878_merged_paternal_fragments_slop_sort_deeptools.bw'
mat_atac = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/Results/GM12878_merged_maternal_fragments_slop_sort_deeptools.bw'
merge_atac = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/GM12878_merged_slop_sort_deeptools.bw'

region_list = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/GM12878_2M_10k_snp_density_summary.txt'
chrom_sizes = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GRCh38_ref/GRCh38.chrom.sizes'
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
        expand('predict/GM12878_pat/prediction/npy/{region}.npy', region=regions),
        expand('predict/GM12878_mat/prediction/npy/{region}.npy', region=regions),
        expand('predict/GM12878_merge/prediction/npy/{region}.npy', region=regions),
        expand('predict/GM12878/prediction/npy/{region}.npy',     region=regions),

rule pat_pred:
    input:
        model = model,
        seq   = seq,
        ctcf  = ctcf,
        atac  = pat_atac,
    output:
        'predict/GM12878_pat/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        # SLURM (--gres=gpu:1) sets CUDA_VISIBLE_DEVICES automatically;
        # do NOT override it here.
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out predict \\
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
        'predict/GM12878_mat/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out predict \\
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
        'predict/GM12878_merge/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out predict \\
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
        'predict/GM12878/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out predict \\
            --celltype GM12878 \\
            --chr $chr --start $start \\
            --model {input.model} \\
            --seq {input.seq} \\
            --ctcf {input.ctcf} \\
            --atac {input.atac}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """
