#!/usr/bin/env python
"""Train C.Origami with ATAC-seq + DNA sequence only (no CTCF)."""
import sys
import torch
import pytorch_lightning as pl
import pytorch_lightning.callbacks as callbacks

from corigami.training.main import TrainModule, init_parser
from corigami.data import genome_dataset
import corigami.model.corigami_models as corigami_models


class TrainModuleATACOnly(TrainModule):
    """TrainModule variant using only ATAC (no CTCF ChIP-seq)."""

    def get_dataset(self, args, mode):
        celltype_root = f'{args.dataset_data_root}/{args.dataset_assembly}/{args.dataset_celltype}'
        genomic_features = {
            'atac': {'file_name': 'atac.bw', 'norm': 'log'}
        }
        dataset = genome_dataset.GenomeDataset(
            celltype_root,
            args.dataset_assembly,
            genomic_features,
            mode=mode,
            include_sequence=True,
            include_genomic_features=True
        )
        if mode == 'val':
            self.val_length = len(dataset) / args.dataloader_batch_size
            print('Validation loader length:', self.val_length)
        return dataset

    def get_model(self, args):
        model_name = args.model_type
        num_genomic_features = 1  # ATAC only
        ModelClass = getattr(corigami_models, model_name)
        model = ModelClass(num_genomic_features, mid_hidden=256)
        return model


def init_training(module_class, args):
    early_stop_callback = callbacks.EarlyStopping(
        monitor='val_loss',
        min_delta=0.00,
        patience=args.trainer_patience,
        verbose=False,
        mode="min"
    )
    checkpoint_callback = callbacks.ModelCheckpoint(
        dirpath=f'{args.run_save_path}/models',
        save_top_k=args.trainer_save_top_n,
        monitor='val_loss'
    )
    lr_monitor = callbacks.LearningRateMonitor(logging_interval='epoch')
    csv_logger = pl.loggers.CSVLogger(save_dir=f'{args.run_save_path}/csv')
    all_loggers = csv_logger

    pl.seed_everything(args.run_seed, workers=True)
    pl_module = module_class(args)
    pl_trainer = pl.Trainer(
        strategy='ddp',
        accelerator="gpu",
        devices=args.trainer_num_gpu,
        gradient_clip_val=1,
        logger=all_loggers,
        callbacks=[early_stop_callback, checkpoint_callback, lr_monitor],
        max_epochs=args.trainer_max_epochs
    )
    trainloader = pl_module.get_dataloader(args, 'train')
    valloader = pl_module.get_dataloader(args, 'val')
    testloader = pl_module.get_dataloader(args, 'test')
    pl_trainer.fit(pl_module, trainloader, valloader)


def main():
    args = init_parser()
    init_training(TrainModuleATACOnly, args)


if __name__ == '__main__':
    main()
