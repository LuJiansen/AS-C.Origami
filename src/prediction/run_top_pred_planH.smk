# Plan H: ATAC-only C.Origami predictions using haplotype-specific DNA and
# ATAC for paternal/maternal outputs, plus bulk DNA and ATAC as a reference.

from pathlib import Path

############################ inputs ############################
REPO_ROOT = Path(workflow.snakefile).resolve().parents[2]
SRC = REPO_ROOT / "src"
DATA = SRC / "data"
CORIGAMI_DATA = DATA / "corigami_data" / "data"
REGION_LIST = DATA / "regions" / "GM12878_2M_10k_snp_density_summary.txt"
CHROM_SIZES = DATA / "reference" / "GRCh38.chrom.sizes"
DSC_ATAC = DATA / "dscNanoATAC"
OUTPUT_ROOT = REPO_ROOT / "outputs/prediction/plan-h"

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
        expand(str(OUTPUT_ROOT / "GM12878_pat/prediction/npy/{region}.npy"), region=regions),
        expand(str(OUTPUT_ROOT / "GM12878_mat/prediction/npy/{region}.npy"), region=regions),
        expand(str(OUTPUT_ROOT / "GM12878_merge/prediction/npy/{region}.npy"), region=regions),
        expand(str(OUTPUT_ROOT / "GM12878_all/prediction/npy/{region}.npy"), region=regions),

rule pat_pred:
    input:
        model = model,
        inference = inference_script,
        seq = pat_seq,
        atac = pat_atac,
    output:
        str(OUTPUT_ROOT / "GM12878_pat/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        python {input.inference} \
            --out {OUTPUT_ROOT} \
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
        str(OUTPUT_ROOT / "GM12878_mat/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        python {input.inference} \
            --out {OUTPUT_ROOT} \
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
        str(OUTPUT_ROOT / "GM12878_merge/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        python {input.inference} \
            --out {OUTPUT_ROOT} \
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
        str(OUTPUT_ROOT / "GM12878_all/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        python {input.inference} \
            --out {OUTPUT_ROOT} \
            --celltype GM12878_all \
            --chr $chr --start $start \
            --model {input.model} \
            --seq {input.seq} \
            --atac {input.atac}
        test -s {output}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """
