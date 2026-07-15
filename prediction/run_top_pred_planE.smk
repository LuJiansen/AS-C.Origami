# Plan E: allele-specific Hi-C prediction via C.Origami.
# Differs from Plan C only in the CTCF track:
#   Plan C → bulk CTCF log2FC * haplotype motif MASK (binary, sparse)
#   Plan E → bulk CTCF log2FC * continuous PWM score ratio (dense, smooth)
#
# DNA sequence and ATAC are identical to Plan B / C / D.
#
# Filename / region convention:
#   <chr>_<predict_start>.npy  (WIN_OFFSET = 0, same as plans A–D)

import os

############################ inputs ############################
model    = 'GM12878/models/epoch=78-step=47004.ckpt'

# Plan E: diploid seq + continuous PWM CTCF + allele-specific ATAC
seq_pat  = 'corigami_data/data/hg38/dna_sequence_diploid/paternal'
seq_mat  = 'corigami_data/data/hg38/dna_sequence_diploid/maternal'
ctcf_pat = 'allele_specific/ctcf_cont/ctcf_log2fc_cont_paternal.bw'
ctcf_mat = 'allele_specific/ctcf_cont/ctcf_log2fc_cont_maternal.bw'
atac_pat = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/Results/GM12878_merged_paternal_fragments_slop_sort_deeptools.bw'
atac_mat = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/Results/GM12878_merged_maternal_fragments_slop_sort_deeptools.bw'
merge_atac = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/GM12878_merged_slop_sort_deeptools.bw'

region_list  = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/GM12878_2M_10k_snp_density_summary.txt'
chrom_sizes  = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GRCh38_ref/GRCh38.chrom.sizes'
TOP_N        = int(config.get("TOP_N", 100))
WIN_OFFSET   = 0
WIN_SIZE     = 2_097_152

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
        if chrom in chrom_size_map and start + WIN_SIZE > chrom_size_map[chrom]:
            continue
        regions.append(f"{chrom}_{start}")
regions = regions[:TOP_N]
print(f"[planE] predicting {len(regions)} regions (top {TOP_N})")

############################ rules ############################
rule all:
    input:
        expand('predict_planE/GM12878_pat_planE/prediction/npy/{region}.npy', region=regions),
        expand('predict_planE/GM12878_mat_planE/prediction/npy/{region}.npy', region=regions),
        expand('predict_planE/GM12878_merge_planE/prediction/npy/{region}.npy', region=regions),

rule pat_pred:
    input:
        model = model,
        seq   = seq_pat,
        ctcf  = ctcf_pat,
        atac  = atac_pat,
    output:
        'predict_planE/GM12878_pat_planE/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        export CUDA_VISIBLE_DEVICES=0
        # Distribute across 2 GPUs by region hash
        # export CUDA_VISIBLE_DEVICES=$(( 0x$(echo {wildcards.region} | cksum | cut -d' ' -f1) % 2 ))
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out predict_planE \\
            --celltype GM12878_pat_planE \\
            --chr $chr --start $start \\
            --model {input.model} \\
            --seq {input.seq} \\
            --ctcf {input.ctcf} \\
            --atac {input.atac}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """

rule mat_pred:
    input:
        model = model,
        seq   = seq_mat,
        ctcf  = ctcf_mat,
        atac  = atac_mat,
    output:
        'predict_planE/GM12878_mat_planE/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        export CUDA_VISIBLE_DEVICES=0
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out predict_planE \\
            --celltype GM12878_mat_planE \\
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
        'predict_planE/GM12878_merge_planE/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out predict_planE \\
            --celltype GM12878_merge_planE \\
            --chr $chr --start $start \\
            --model {input.model} \\
            --seq {input.seq} \\
            --ctcf {input.ctcf} \\
            --atac {input.atac}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """