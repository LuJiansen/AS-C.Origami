#!/bin/bash
#SBATCH -p gpu_4l
#SBATCH -c 28
#SBATCH -N 1
#SBATCH -J LJS_TEST
#SBATCH --gres=gpu:4
#SBATCH -o corigami.%j.out
#SBATCH -e corigami.%j.err
#SBATCH -A tangfuchou_g1
#SBATCH --qos=Tangfuchoug4c

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export CUDA_VISIBLE_DEVICES=0

OUTPUT_DIR="${REPO_ROOT}/outputs/training/standard"
mkdir -p "${OUTPUT_DIR}"

corigami-train \
    --data-root "${REPO_ROOT}/src/data/corigami_data/data" \
    --assembly hg38 \
    --celltype gm12878 \
    --save_path "${OUTPUT_DIR}" \
    --num-gpu 1 > "${OUTPUT_DIR}/training.log" 2>&1
