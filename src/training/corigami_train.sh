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

export CUDA_VISIBLE_DEVICES=0

corigami-train \
    --data-root corigami_data/data \
    --assembly hg38 \
    --celltype gm12878 \
    --save_path GM12878 \
    --num-gpu 1 > training.log