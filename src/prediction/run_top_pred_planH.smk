# Plan H: ATAC-only C.Origami predictions using haplotype-specific DNA and
# ATAC for paternal/maternal outputs, plus bulk DNA and ATAC as a reference.

############################ inputs ############################
model = 'GM12878_ATAC_ONLY/models/epoch=46-step=55929.ckpt'
inference_script = 'predict_atac_only.py'

pat_seq = 'corigami_data/data/hg38/dna_sequence_diploid/paternal'
mat_seq = 'corigami_data/data/hg38/dna_sequence_diploid/maternal'
bulk_seq = 'corigami_data/data/hg38/dna_sequence'

pat_atac = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/Results/GM12878_merged_paternal_fragments_slop_sort_deeptools.bw'
mat_atac = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/Results/GM12878_merged_maternal_fragments_slop_sort_deeptools.bw'
bulk_atac = 'corigami_data/data/hg38/gm12878/genomic_features/atac.bw'
merge_atac = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/project/LW_TEST/10XATAC/analysis/GM12878_merged_noerror/GM12878_merged_slop_sort_deeptools.bw'

region_list = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GM12878/GM12878/GM12878_2M_10k_snp_density_summary.txt'
chrom_sizes = '/gpfs1/tangfuchou_pkuhpc/tangfuchou_test/lujiansen/database/GRCh38_ref/GRCh38.chrom.sizes'
TOP_N = int(config.get("TOP_N", 5000))
WIN_OFFSET = 0
WIN_SIZE = 2_097_152

############################ chromosome sizes ############################
chrom_size_map = {}
with open(chrom_sizes) as f:
    for line in f:
        fields = line.strip().split()
        if len(fields) < 2:
            continue
        try:
            chrom_size_map[fields[0]] = int(fields[1])
        except ValueError:
            continue

############################ region list ############################
regions = []
with open(region_list) as f:
    next(f, None)  # skip header
    for line in f:
        fields = line.strip().split()
        if len(fields) < 2:
            continue
        chrom = fields[0]
        try:
            start = int(fields[1]) - WIN_OFFSET
        except ValueError:
            continue
        if start < 0:
            continue
        if chrom in chrom_size_map and start + WIN_SIZE > chrom_size_map[chrom]:
            continue
        regions.append(f"{chrom}_{start}")

regions = regions[:TOP_N]

print(f"[planH] predicting {len(regions)} regions (top {TOP_N})")

############################ rules ############################
rule all:
    input:
        expand('predict_atac_model/GM12878_pat/prediction/npy/{region}.npy', region=regions),
        expand('predict_atac_model/GM12878_mat/prediction/npy/{region}.npy', region=regions),
        expand('predict_atac_model/GM12878_merge/prediction/npy/{region}.npy', region=regions),
        expand('predict_atac_model/GM12878_all/prediction/npy/{region}.npy', region=regions),

rule pat_pred:
    input:
        model = model,
        inference = inference_script,
        seq = pat_seq,
        atac = pat_atac,
    output:
        'predict_atac_model/GM12878_pat/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        python {input.inference} \
            --out predict_atac_model \
            --celltype GM12878_pat \
            --chr $chr --start $start \
            --model {input.model} \
            --seq {input.seq} \
            --atac {input.atac}
        test -s {output}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """

rule mat_pred:
    input:
        model = model,
        inference = inference_script,
        seq = mat_seq,
        atac = mat_atac,
    output:
        'predict_atac_model/GM12878_mat/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        python {input.inference} \
            --out predict_atac_model \
            --celltype GM12878_mat \
            --chr $chr --start $start \
            --model {input.model} \
            --seq {input.seq} \
            --atac {input.atac}
        test -s {output}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """

rule merge_pred:
    input:
        model = model,
        inference = inference_script,
        seq = bulk_seq,
        atac = merge_atac,
    output:
        'predict_atac_model/GM12878_merge/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        python {input.inference} \
            --out predict_atac_model \
            --celltype GM12878_merge \
            --chr $chr --start $start \
            --model {input.model} \
            --seq {input.seq} \
            --atac {input.atac}
        test -s {output}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """

rule all_pred:
    input:
        model = model,
        inference = inference_script,
        seq = bulk_seq,
        atac = bulk_atac,
    output:
        'predict_atac_model/GM12878_all/prediction/npy/{region}.npy',
    shell: """
        set +u; source activate corigami; set -u
        export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        python {input.inference} \
            --out predict_atac_model \
            --celltype GM12878_all \
            --chr $chr --start $start \
            --model {input.model} \
            --seq {input.seq} \
            --atac {input.atac}
        test -s {output}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """
