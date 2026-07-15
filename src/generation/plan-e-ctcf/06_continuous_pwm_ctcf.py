#!/usr/bin/env python3
"""06_continuous_pwm_ctcf.py — Build continuous PWM-modulated allele-specific CTCF bigWigs.

Formula: ctcf_hap = bulk_ctcf × max(hap_pwm_score, ε) / max(ref_pwm_score, ε)

Only positions within ±150 bp of a CTCF-motif-overlapping phased SNP get a
factor ≠ 1.0. Factors are Gaussian-smoothed (σ=50 bp) and clamped to [0.1, 2.0].
"""

import sys
import os
import gzip
import argparse
from pathlib import Path

import numpy as np
import pyBigWig
import pysam

EPSILON = 1e-6
MIN_SCORE = 0.01
FACTOR_MIN = 0.1
FACTOR_MAX = 2.0
SIGMA = 50          # Gaussian sigma in bp
HALF_WIDTH = 150    # 3σ — truncate Gaussian beyond this
MOTIF_WIDTH = 19    # MA0139.1 width

def parse_meme_pwm(meme_path):
    """Parse MA0139.1 MEME file → log-odds PWM matrix (motif_width × 4).

    MEME letter-probability matrix is 19 rows × 4 columns (A, C, G, T).
    Log-odds = log2(p_letter / 0.25)."""
    with open(meme_path) as f:
        lines = f.readlines()

    # Find the letter-probability matrix start
    in_matrix = False
    rows = []
    for line in lines:
        if line.startswith("MOTIF"):
            continue
        if "letter-probability matrix" in line:
            in_matrix = True
            continue
        if in_matrix:
            parts = line.strip().split()
            if len(parts) == 4:
                rows.append([float(x) for x in parts])
            elif len(rows) > 0:
                break

    pwm = np.array(rows)  # shape (19, 4), order A C G T
    # Convert to log-odds: log2(p / 0.25)
    pwm[pwm == 0] = EPSILON
    log_odds = np.log2(pwm / 0.25)
    return log_odds

# Nucleotide → column index
NT_TO_IDX = {"A": 0, "a": 0, "C": 1, "c": 1, "G": 2, "g": 2, "T": 3, "t": 3}

def score_sequence(seq, log_odds_pwm):
    """Score a sequence of length == motif_width against the PWM.

    Returns the sum of log-odds values at each position."""
    total = 0.0
    for i, nt in enumerate(seq):
        idx = NT_TO_IDX.get(nt)
        if idx is None:
            return 0.0  # N or ambiguous base → score 0
        total += log_odds_pwm[i, idx]
    return total

def scan_vcf(vcf_path, fasta, log_odds_pwm, target_chroms):
    """Scan phased VCF, return qualifying SNP events.

    An event is (chrom, pos, ref_score, ref_seq, hap1, hap2, ref_allele, alt_allele) for SNPs where
    ref_score >= MIN_SCORE, meaning the SNP overlaps a CTCF motif.

    Uses pysam for random-access fasta extraction (requires .fai index)."""
    events = []
    half_motif = MOTIF_WIDTH // 2  # 9

    with gzip.open(vcf_path, "rt") as f:
        for line in f:
            if line.startswith("#"):
                continue
            parts = line.strip().split("\t")
            if len(parts) < 10:
                continue

            chrom = parts[0]
            if chrom not in target_chroms:
                continue

            pos = int(parts[1]) - 1  # VCF is 1-based, convert to 0-based
            ref_allele = parts[3]
            alt_allele = parts[4]
            fmt = parts[8]
            sample = parts[9]

            # Skip indels, multi-allelic
            if len(ref_allele) != 1 or len(alt_allele) != 1:
                continue

            # Parse GT from sample column
            fmt_fields = fmt.split(":")
            sample_fields = sample.split(":")
            gt_idx = fmt_fields.index("GT") if "GT" in fmt_fields else -1
            if gt_idx < 0:
                continue
            gt = sample_fields[gt_idx]

            # Must be phased (contains |)
            if "|" not in gt:
                continue
            hap1, hap2 = gt.split("|")
            if hap1 not in ("0", "1") or hap2 not in ("0", "1"):
                continue

            # Extract reference sequence ± half_motif around SNP
            fetch_start = pos - half_motif
            fetch_end = pos + half_motif + 1  # +1 for the SNP base itself
            try:
                ref_seq = fasta.fetch(chrom, fetch_start, fetch_end).upper()
            except (ValueError, KeyError):
                continue  # out of bounds or contig not in fasta

            if len(ref_seq) != MOTIF_WIDTH:
                continue

            # Score reference sequence
            ref_score = score_sequence(ref_seq, log_odds_pwm)
            if ref_score < MIN_SCORE:
                continue  # SNP not near a CTCF motif

            events.append((chrom, pos, ref_score, ref_seq, hap1, hap2, ref_allele, alt_allele))

    return events


def compute_factor(ref_score, hap_score):
    """Compute modulation factor for one haplotype.

    factor = max(hap_score, ε) / max(ref_score, ε), clamped to [FACTOR_MIN, FACTOR_MAX]."""
    ref = max(ref_score, EPSILON)
    hap = max(hap_score, EPSILON)
    factor = hap / ref
    return np.clip(factor, FACTOR_MIN, FACTOR_MAX)


def build_haplotype_ctcf_bigwig(events, fasta, log_odds_pwm,
                                bulk_ctcf_path, chrom_sizes, out_path,
                                hap_idx):
    """Build one allele-specific CTCF bigWig by applying SNP-modulated factors
    directly to bulk CTCF in memory (no intermediate wiggletools).

    hap_idx: 0 for the first allele in GT (hap1/paternal),
             1 for the second allele in GT (hap2/maternal).

    Processes each chromosome in 2 Mb chunks. For each chunk:
    1. Read bulk CTCF values
    2. Apply Gaussian-smoothed factor modifications
    3. Multiply: output = bulk * factors
    4. Write directly to output bigWig"""
    chrom_size_map = {}
    with open(chrom_sizes) as f:
        for line in f:
            c, s = line.strip().split()[:2]
            chrom_size_map[c] = int(s)

    # Filter events to target chroms and compute per-haplotype factors
    target_chroms = set(chrom_size_map.keys())
    chrom_events = {}
    for ev in events:
        chrom, pos, ref_score, ref_seq, h1, h2, ref_allele, alt_allele = ev
        if chrom not in target_chroms:
            continue

        gt_val = h1 if hap_idx == 0 else h2
        if gt_val == "0":
            hap_score = ref_score
        else:
            snp_offset = MOTIF_WIDTH // 2
            hap_seq = ref_seq[:snp_offset] + alt_allele.upper() + ref_seq[snp_offset + 1:]
            hap_score = score_sequence(hap_seq, log_odds_pwm)

        factor = compute_factor(ref_score, hap_score)
        if abs(factor - 1.0) < 1e-6:
            continue

        chrom_events.setdefault(chrom, []).append((pos, factor))

    if sum(len(v) for v in chrom_events.values()) == 0:
        print("[06] WARNING: No modulating events — copying bulk CTCF directly")

    # Open bulk CTCF for reading
    bulk_bw = pyBigWig.open(bulk_ctcf_path)

    # Write output bigWig
    out_bw = pyBigWig.open(out_path, "w")
    out_bw.addHeader(list(chrom_size_map.items()))

    CHUNK = 2_000_000  # 2 Mb chunks for memory efficiency

    for chrom in sorted(target_chroms):
        c_len = chrom_size_map[chrom]
        # Clamp to actual bigWig chrom length (may differ from chrom.sizes)
        bulk_chrom_len = bulk_bw.chroms(chrom)
        if bulk_chrom_len is None:
            continue
        effective_len = min(c_len, bulk_chrom_len)
        events_list = sorted(chrom_events.get(chrom, []), key=lambda x: x[0])

        for chunk_start in range(0, effective_len, CHUNK):
            chunk_end = min(chunk_start + CHUNK, effective_len)
            n = chunk_end - chunk_start

            # Read bulk CTCF for this chunk
            bulk_vals = np.nan_to_num(
                np.array(bulk_bw.values(chrom, chunk_start, chunk_end)),
                0).astype(np.float32)

            factors = np.ones(n, dtype=np.float32)

            # Apply Gaussian-smoothed factor modifications
            lo_pos = chunk_start - HALF_WIDTH
            hi_pos = chunk_end + HALF_WIDTH
            for pos, factor_val in events_list:
                if pos < lo_pos:
                    continue
                if pos > hi_pos:
                    break

                center = pos - chunk_start
                win_lo = max(0, center - HALF_WIDTH)
                win_hi = min(n, center + HALF_WIDTH + 1)
                offsets = np.arange(win_lo - center, win_hi - center, dtype=np.float64)
                weights = np.exp(-0.5 * (offsets / SIGMA) ** 2)
                modulated = 1.0 + (factor_val - 1.0) * weights.astype(np.float32)
                factors[win_lo:win_hi] = np.minimum(factors[win_lo:win_hi], modulated)

            # Apply factors
            result = bulk_vals * factors

            # Bin to 50bp and write as bedGraph entries (compact)
            BIN_SIZE = 50
            n_bins = n // BIN_SIZE
            if n_bins == 0:
                continue
            binned = result[:n_bins * BIN_SIZE].reshape(n_bins, BIN_SIZE).mean(axis=1)

            chroms_list = [chrom] * n_bins
            starts_list = [chunk_start + i * BIN_SIZE for i in range(n_bins)]
            ends_list = [s + BIN_SIZE for s in starts_list]
            out_bw.addEntries(chroms_list, starts_list,
                              ends=ends_list, values=binned.tolist())

    bulk_bw.close()
    out_bw.close()


def default_paths():
    repo_root = Path(__file__).resolve().parents[3]
    data_root = repo_root / "src" / "data"
    corigami = data_root / "corigami_data" / "data"
    return {
        "meme": Path(__file__).with_name("MA0139.1.meme"),
        "vcf": repo_root / "src/data/variants/illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz",
        "ref_fasta": corigami / "hg38" / "dna_sequence" / "hg38.fa",
        "bulk_ctcf": corigami / "hg38" / "gm12878" / "genomic_features" / "ctcf_log2fc.bw",
        "chrom_sizes": data_root / "reference" / "GRCh38.chrom.sizes",
        "out_dir": corigami / "hg38" / "gm12878" / "genomic_features" / "plan-e",
    }


def parse_args():
    defaults = default_paths()
    p = argparse.ArgumentParser(description="Plan E: continuous PWM-modulated allele-specific CTCF")
    p.add_argument("--meme", default=str(defaults["meme"]), help="Path to MA0139.1.meme PWM file")
    p.add_argument("--vcf", default=str(defaults["vcf"]), help="Path to phased VCF (.vcf.gz)")
    p.add_argument("--ref-fasta", default=str(defaults["ref_fasta"]), help="Path to hg38 reference fasta")
    p.add_argument("--bulk-ctcf", default=str(defaults["bulk_ctcf"]), help="Path to bulk CTCF log2FC bigWig")
    p.add_argument("--chrom-sizes", default=str(defaults["chrom_sizes"]), help="Path to hg38 chrom.sizes file")
    p.add_argument("--out-dir", default=str(defaults["out_dir"]), help="Output directory for allele-specific bigWigs")
    p.add_argument("--chroms", default=None, help="Comma-separated list of chromosomes (default: chr1-chr22,chrX)")
    return p.parse_args()

def main():
    args = parse_args()

    # Determine target chromosomes
    if args.chroms:
        target_chroms = set(args.chroms.split(","))
    else:
        target_chroms = {f"chr{i}" for i in range(1, 23)} | {"chrX"}

    print(f"[06] Loading PWM: {args.meme}")
    log_odds_pwm = parse_meme_pwm(args.meme)

    print(f"[06] Opening reference: {args.ref_fasta}")
    fasta = pysam.FastaFile(args.ref_fasta)

    print(f"[06] Scanning VCF: {args.vcf}")
    events = scan_vcf(args.vcf, fasta, log_odds_pwm, target_chroms)
    print(f"[06] Qualifying SNP-motif overlaps: {len(events)}")

    os.makedirs(args.out_dir, exist_ok=True)

    for hap_idx, hap_label in [(0, "paternal"), (1, "maternal")]:
        print(f"[06] Building {hap_label} CTCF bigWig...")
        out_path = os.path.join(args.out_dir, f"ctcf_log2fc_cont_{hap_label}.bw")
        build_haplotype_ctcf_bigwig(
            events, fasta, log_odds_pwm,
            args.bulk_ctcf, args.chrom_sizes,
            out_path, hap_idx)

    fasta.close()
    print(f"[06] Done. Outputs in {args.out_dir}/")
    print(f"  ctcf_log2fc_cont_paternal.bw")
    print(f"  ctcf_log2fc_cont_maternal.bw")

if __name__ == "__main__":
    main()
