#!/bin/bash
# 01_build_haplotype_fasta.sh
# Build paternal/maternal haplotype-specific fasta files compatible with C.Origami.
#
# Strategy:
#   - Use a *phased* single-sample VCF (e.g. GIAB GM12878 v4.2.1, 1000G phased calls,
#     WhatsHap output, etc.).
#   - Restrict to bi-allelic SNPs only — indels would shift downstream coordinates
#     and break alignment with the hg38-coordinate Hi-C / bigwig signals.
#   - bcftools consensus -H 1pIu / -H 2pIu writes haplotype 1 / 2; for unphased het
#     it falls back to IUPAC code (acceptable since our other inputs are hg38-aligned).
#   - Output is per-chromosome bgzip-ed fasta named  chrN.fa.gz  to drop into
#     C.Origami's   <celltype_root>/../dna_sequence/   layout.
#
# Required tools: bcftools (>=1.10), samtools, bgzip, tabix
#
# Usage: bash 01_build_haplotype_fasta.sh [reference.fa] [phased.vcf.gz] [output_dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
DATA_ROOT="${REPO_ROOT}/src/data/corigami_data/data"

REF="${1:-${DATA_ROOT}/hg38/dna_sequence/hg38.fa}"
VCF="${2:-${REPO_ROOT}/src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz}"
OUT="${3:-${DATA_ROOT}/hg38/dna_sequence_diploid}"
SAMPLE="${SAMPLE:-NA12878}"
THREADS="${THREADS:-4}"

PAT_DIR="${OUT}/paternal"       # haplotype 1
MAT_DIR="${OUT}/maternal"       # haplotype 2
mkdir -p "${PAT_DIR}" "${MAT_DIR}"

# Sanity: ensure index files exist
[[ -f "${REF}.fai" ]] || samtools faidx "${REF}"
[[ -f "${VCF}.tbi" || -f "${VCF}.csi" ]] || tabix -p vcf "${VCF}"

# ---- 1. Pre-filter: keep only bi-allelic SNPs for the chosen sample ----
SNP_VCF="${OUT}/$(basename "${VCF}" .vcf.gz).${SAMPLE}.snps.vcf.gz"
if [[ ! -s "${SNP_VCF}" ]]; then
    bcftools view --threads "${THREADS}" \
        -s "${SAMPLE}" -m2 -M2 -v snps -Oz -o "${SNP_VCF}" "${VCF}"
    tabix -f -p vcf "${SNP_VCF}"
fi
echo "[01] SNP-only VCF: $SNP_VCF"

# ---- 2. Per-chromosome consensus ----
CHRS=$(seq -f 'chr%g' 1 22)
CHRS="$CHRS chrX"          # add chrY if your sample is male and you want it

for chr in $CHRS; do
    echo "[01] $chr  (paternal)"
    samtools faidx "${REF}" "${chr}" \
        | bcftools consensus -s "${SAMPLE}" -H 1pIu "${SNP_VCF}" \
        | awk -v c="${chr}" 'NR==1{print ">"c; next} {print}' \
        | bgzip -@ "${THREADS}" -c > "${PAT_DIR}/${chr}.fa.gz"

    echo "[01] $chr  (maternal)"
    samtools faidx "${REF}" "${chr}" \
        | bcftools consensus -s "${SAMPLE}" -H 2pIu "${SNP_VCF}" \
        | awk -v c="${chr}" 'NR==1{print ">"c; next} {print}' \
        | bgzip -@ "${THREADS}" -c > "${MAT_DIR}/${chr}.fa.gz"
done

echo "[01] Done. Use these dirs as --seq for corigami-predict:"
echo "     paternal: $PAT_DIR"
echo "     maternal: $MAT_DIR"
