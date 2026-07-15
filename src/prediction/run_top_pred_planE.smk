# Plan E: allele-specific Hi-C prediction via C.Origami.
# Differs from Plan C only in the CTCF track:
#   Plan C → bulk CTCF log2FC * haplotype motif MASK (binary, sparse)
#   Plan E → bulk CTCF log2FC * continuous PWM score ratio (dense, smooth)
#
# DNA sequence and ATAC are identical to Plan B / C / D.
#
# Filename / region convention:
#   <chr>_<predict_start>.npy  (WIN_OFFSET = 0, same as plans A–D)

from pathlib import Path

############################ inputs ############################
REPO_ROOT = Path(workflow.snakefile).resolve().parents[2]
SRC = REPO_ROOT / "src"
DATA = SRC / "data"
CORIGAMI_DATA = DATA / "corigami_data" / "data"
REGION_LIST = DATA / "regions" / "GM12878_2M_10k_snp_density_summary.txt"
CHROM_SIZES = DATA / "reference" / "GRCh38.chrom.sizes"
DSC_ATAC = DATA / "dscNanoATAC"
OUTPUT_ROOT = REPO_ROOT / "outputs/prediction/plan-e"

model = str(SRC / "models" / "standard" / "epoch=78-step=47004.ckpt")

# Plan E: diploid seq + continuous PWM CTCF + allele-specific ATAC
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
        expand(str(OUTPUT_ROOT / "GM12878_pat_planE/prediction/npy/{region}.npy"), region=regions),
        expand(str(OUTPUT_ROOT / "GM12878_mat_planE/prediction/npy/{region}.npy"), region=regions),
        expand(str(OUTPUT_ROOT / "GM12878_merge_planE/prediction/npy/{region}.npy"), region=regions),

rule pat_pred:
    input:
        model = model,
        seq   = seq_pat,
        ctcf  = ctcf_pat,
        atac  = atac_pat,
    output:
        str(OUTPUT_ROOT / "GM12878_pat_planE/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        export CUDA_VISIBLE_DEVICES=0
        # Distribute across 2 GPUs by region hash
        # export CUDA_VISIBLE_DEVICES=$(( 0x$(echo {wildcards.region} | cksum | cut -d' ' -f1) % 2 ))
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out {OUTPUT_ROOT} \\
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
        str(OUTPUT_ROOT / "GM12878_mat_planE/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        export CUDA_VISIBLE_DEVICES=0
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out {OUTPUT_ROOT} \\
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
        seq   = bulk_seq,
        ctcf  = bulk_ctcf,
        atac  = merge_atac,
    output:
        str(OUTPUT_ROOT / "GM12878_merge_planE/prediction/npy/{region}.npy"),
    shell: """
        set +u; source activate corigami; set -u
        chr=`echo {wildcards.region} | sed 's/_.*//g'`
        start=`echo {wildcards.region} | sed 's/.*_//g'`
        corigami-predict \\
            --out {OUTPUT_ROOT} \\
            --celltype GM12878_merge_planE \\
            --chr $chr --start $start \\
            --model {input.model} \\
            --seq {input.seq} \\
            --ctcf {input.ctcf} \\
            --atac {input.atac}
        set +u; conda deactivate; set -u
        ls -l {output} >/dev/null
    """
