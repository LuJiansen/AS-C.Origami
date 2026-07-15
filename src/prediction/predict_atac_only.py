#!/usr/bin/env python
"""Single-region prediction for ATAC-only C.Origami model (no CTCF input)."""
import os
import sys
import argparse
import numpy as np
import torch

from corigami.data.data_feature import SequenceFeature, GenomicFeature
import corigami.model.corigami_models as corigami_models


def main():
    parser = argparse.ArgumentParser(
        description='C.Origami ATAC-only Prediction Module.'
    )
    parser.add_argument('--out', dest='output_path', default='outputs',
                        help='output path for storing results (default: %(default)s)')
    parser.add_argument('--celltype', dest='celltype',
                        help='Sample cell type for prediction, used for output separation',
                        required=True)
    parser.add_argument('--chr', dest='chr_name',
                        help='Chromosome for prediction', required=True)
    parser.add_argument('--start', dest='start', type=int,
                        help='Starting point for prediction (width is 2097152 bp)',
                        required=True)
    parser.add_argument('--model', dest='model_path',
                        help='Path to the model checkpoint', required=True)
    parser.add_argument('--seq', dest='seq_path',
                        help='Path to the folder where the sequence .fa.gz files are stored',
                        required=True)
    parser.add_argument('--atac', dest='atac_path',
                        help='Path to the ATAC-seq .bw file',
                        required=True)

    args = parser.parse_args(args=None if sys.argv[1:] else ['--help'])
    single_prediction(
        args.output_path, args.celltype,
        args.chr_name, args.start,
        args.model_path,
        args.seq_path, args.atac_path
    )


def single_prediction(output_path, celltype, chr_name, start,
                      model_path, seq_path, atac_path):
    window = 2097152
    end = start + window

    # Load DNA sequence
    seq_chr_path = os.path.join(seq_path, f'{chr_name}.fa.gz')
    seq_feat = SequenceFeature(path=seq_chr_path)
    seq_region = seq_feat.get(start, end)  # (window, 5) one-hot

    # Load ATAC
    atac_feat = GenomicFeature(path=atac_path, norm='log')
    atac_region = atac_feat.get(chr_name, start, end)  # (window,)

    # Preprocess: DNA 5-ch one-hot + ATAC 1-ch log → (1, window, 6)
    seq_tensor = torch.tensor(seq_region).unsqueeze(0)
    atac_tensor = torch.tensor(
        np.nan_to_num(atac_region, 0)
    ).unsqueeze(0).unsqueeze(2)
    inputs = torch.cat([seq_tensor, atac_tensor], dim=2)

    device = torch.device("cuda" if torch.cuda.is_available() else "cpu")
    inputs = inputs.to(device)

    # Load model
    model = load_model_atac_only(model_path, device)

    # Predict
    with torch.no_grad():
        pred = model(inputs)[0].detach().cpu().numpy()

    # Save
    out_dir = os.path.join(output_path, celltype, 'prediction', 'npy')
    os.makedirs(out_dir, exist_ok=True)
    out_file = os.path.join(out_dir, f'{chr_name}_{start}.npy')
    np.save(out_file, pred)
    print(f'Saved prediction to {out_file}')


def load_model_atac_only(model_path, device):
    model = corigami_models.ConvTransModel(
        num_genomic_features=1, mid_hidden=256
    )
    model.to(device)

    checkpoint = torch.load(model_path, map_location=device, weights_only=False)
    model_weights = checkpoint['state_dict']

    # Strip 'model.' prefix added by Lightning
    for key in list(model_weights):
        model_weights[key.replace('model.', '')] = model_weights.pop(key)

    model.load_state_dict(model_weights)
    model.eval()
    return model


if __name__ == '__main__':
    main()
