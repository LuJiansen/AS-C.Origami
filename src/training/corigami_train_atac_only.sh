#!/bin/bash
#SBATCH -p gpu_2l
#SBATCH -c 5
#SBATCH -N 1
#SBATCH -J ATAC_ONLY
#SBATCH --gres=gpu:1
#SBATCH -o corigami_atac_only.%j.out
#SBATCH -e corigami_atac_only.%j.err
#SBATCH -A tangfuchou_g1
#SBATCH --qos=Tangfuchoug2c

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"

export CUDA_VISIBLE_DEVICES=0
export http_proxy=""; export https_proxy=""; export no_proxy="*"
export OFFLINE=1; export TORCH_HUB_OFFLINE=1

if ! command -v conda >/dev/null 2>&1; then
    echo "conda is required on PATH before submitting this launcher" >&2
    exit 1
fi
eval "$(conda shell.bash hook)"
conda activate "${CORIGAMI_ENV:-corigami}"

OUTPUT_DIR="${REPO_ROOT}/outputs/training/atac-only"
mkdir -p "${OUTPUT_DIR}"

python "${REPO_ROOT}/src/training/train_atac_only.py" \
    --data-root "${REPO_ROOT}/src/data/corigami_data/data" \
    --assembly hg38 \
    --celltype gm12878 \
    --save_path "${OUTPUT_DIR}" \
    --num-gpu 1 \
    --batch-size 4 \
    --num-workers 2 \
    --ddp-disabled &> "${OUTPUT_DIR}/training.log"
