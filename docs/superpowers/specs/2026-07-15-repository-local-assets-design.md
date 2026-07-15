# AS-C.Origami 仓库本地资源化设计

## 状态与目标

本设计扩展 `2026-07-15-as-c-origami-archive-design.md`。旧设计要求八个工作流文件
原样归档并排除模型、数据和辅助脚本；用户后续明确要求将训练和预测所需代码、选定的
模型与数据放入 `src/`，并将对应路径改为仓库相对路径。因此，本设计覆盖旧设计中与
文件布局、归档范围和路径不可修改策略冲突的部分。

目标是让仓库清楚区分以下内容：

- 可直接纳入版本控制的训练、预测和数据生成代码；
- 通过 Git LFS 保存的模型及关键 GM12878 输入数据；
- 因体积较大而不上传、但能从公开来源获取或由仓库代码生成的数据；
- 保留已有输出、供结果参考的 SNP density 与 benchmark notebook。

所有运行入口从自身位置推导仓库根目录，不依赖启动命令时的当前工作目录。新产生的
训练与预测结果写入仓库根目录下的 `outputs/`，不覆盖归档 checkpoint。

## 仓库布局

```text
AS-C.Origami/
├── src/
│   ├── training/
│   │   ├── corigami_train.sh
│   │   ├── corigami_train_atac_only.sh
│   │   └── train_atac_only.py
│   ├── prediction/
│   │   ├── run_top_pred.smk
│   │   ├── run_top_pred_planE.smk
│   │   ├── run_top_pred_planH.smk
│   │   └── predict_atac_only.py
│   ├── generation/
│   │   ├── diploid-dna/
│   │   │   └── 01_build_haplotype_fasta.sh
│   │   └── plan-e-ctcf/
│   │       ├── 06_continuous_pwm_ctcf.py
│   │       └── MA0139.1.meme
│   ├── models/
│   │   ├── standard/epoch=78-step=47004.ckpt
│   │   └── atac-only/epoch=46-step=55929.ckpt
│   └── data/
│       ├── dscNanoATAC/
│       │   ├── GM12878_dscNanoATAC_paternal.bw
│       │   ├── GM12878_dscNanoATAC_maternal.bw
│       │   └── GM12878_dscNanoATAC_merged.bw
│       ├── variants/
│       │   ├── illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz
│       │   └── illumina_PlatinumGenomes_2017_hg38_NA12878_PS.vcf.gz.tbi
│       ├── regions/
│       │   └── GM12878_2M_10k_snp_density_summary.txt
│       ├── reference/
│       │   └── GRCh38.chrom.sizes
│       └── corigami_data/
│           └── data/
├── snp-density/SNP_density.ipynb
├── benchmarks/
├── outputs/
│   ├── training/
│   └── prediction/
└── docs/
```

`src/data/corigami_data/data/` 是解压公开 C.Origami GM12878 数据包后的固定位置。该
目录的批量数据不提交到 Git；仅保留说明文件或目录占位。`outputs/` 作为运行产物目录
并由 Git 忽略。

仓库根目录现有的 `training/` 与 `prediction/` 文件迁入 `src/`，避免保留两套可能
继续分叉的运行入口。Notebook 继续放在当前面向分析的目录中。

## 纳入范围与来源

### 代码

除已有的两个训练 shell 脚本和三个预测 Snakefile 外，纳入这些流程实际调用的代码：

- `train_atac_only.py`：ATAC-only 训练入口，来源于集群 C.Origami 工作目录；
- `predict_atac_only.py`：Plan H 推理入口，来源于同一工作目录；
- `01_build_haplotype_fasta.sh`：使用 phased VCF 生成父系和母系 DNA sequence；
- `06_continuous_pwm_ctcf.py` 与 `MA0139.1.meme`：生成 Plan E 父系和母系连续
  PWM CTCF BigWig。

`docs/source-manifest.tsv` 继续记录每个代码文件的原始绝对路径和导入前 SHA-256。
修改过仓库路径的文件另外记录仓库版本 SHA-256，不能再将其描述为逐字节副本。

### 直接上传的数据和模型

下列文件随私有仓库分发：

- 标准模型 checkpoint `epoch=78-step=47004.ckpt`；
- ATAC-only 模型 checkpoint `epoch=46-step=55929.ckpt`；
- GM12878 dscNanoATAC 父系、母系和合并 BigWig；
- SNP density 区域汇总表；
- `GRCh38.chrom.sizes`；
- NA12878/GM12878 phased VCF 及其 tabix 索引。

dscNanoATAC 的细胞系必须体现在文件名中，统一使用
`GM12878_dscNanoATAC_{paternal,maternal,merged}.bw`。VCF 使用能同时体现公开项目、
参考版本和样本的文件名。

### 公开下载或生成的数据

原始 `dna_sequence`、GM12878 bulk CTCF/ATAC 等 C.Origami 数据来自：

`https://zenodo.org/record/7226561/files/corigami_data_gm12878_add_on.tar.gz?download=1`

这些数据不重复上传。README 提供下载、校验和解压到
`src/data/corigami_data/data/` 的命令及预期目录结构。

上传的 phased VCF 来源标注为 Illumina Platinum Genomes：

`https://github.com/Illumina/PlatinumGenomes`

同一份原始 VCF 同时供 SNP density 计算和 diploid DNA 生成使用。diploid DNA 脚本
产生的 SNP-only VCF 属于可重建中间文件，不上传第二份。父系/母系
`dna_sequence_diploid` 和 Plan E 父系/母系 CTCF BigWig 也不上传，由仓库内代码生成。

## 路径与运行行为

### 训练

训练脚本根据自身路径定位仓库根目录，调用 `src/training/` 中的 Python 入口，并将
`--data-root` 指向 `src/data/corigami_data/data/`。标准与 ATAC-only 训练输出分别写入
`outputs/training/standard/` 和 `outputs/training/atac-only/`。集群资源声明和已验证的
训练参数保持不变；只移除对旧 C.Origami 工作目录的依赖。

### 预测

三个 Snakefile 使用 Snakefile 所在位置计算仓库根目录，并从以下固定位置读取资源：

- checkpoint：`src/models/standard/` 或 `src/models/atac-only/`；
- dscNanoATAC：`src/data/dscNanoATAC/`；
- 区域表和染色体长度：`src/data/regions/`、`src/data/reference/`；
- bulk DNA、CTCF 与 ATAC：`src/data/corigami_data/data/`；
- diploid DNA：`src/data/corigami_data/data/hg38/dna_sequence_diploid/`；
- Plan E CTCF：`src/data/corigami_data/data/hg38/gm12878/genomic_features/plan-e/`；
- Plan H Python 推理入口：相对 Snakefile 定位的 `src/prediction/predict_atac_only.py`。

Plan A、E、H 输出分别写到 `outputs/prediction/plan-a/`、`plan-e/` 和 `plan-h/`。
Plan E 的 merge 规则当前引用未定义的 `seq` 和 `ctcf`，实现时改为明确使用 bulk DNA
和 bulk CTCF；父系和母系规则仍使用各自的 diploid DNA 与连续 PWM CTCF。

### 数据生成

diploid DNA 脚本默认读取上传的 phased VCF 和 Zenodo bulk DNA，输出到上述
`dna_sequence_diploid/`。Plan E CTCF 脚本默认读取 phased VCF、bulk CTCF 所需输入和
PWM，输出到上述 `plan-e/`。两者允许通过命令行参数覆盖默认值，但文档示例使用仓库
布局。

`SNP_density.ipynb` 改为读取仓库内 VCF 和染色体长度文件，并在 notebook 内生成所需
的 10 kb 与 500 kb 窗口，避免依赖未上传的预生成 BED。其现有输出单元全部保留；修改
只作用于代码和说明单元。最终区域汇总表写入 `src/data/regions/`。

### Benchmark

两个 benchmark notebook 保留现有输出用于参考。与预测结果有关的代码路径按新的
`outputs/prediction/` 布局更新；Dip3D、参考矩阵或其他未纳入仓库的 benchmark 输入
继续作为外部依赖记录，不扩展本次数据上传范围。

## Git LFS 与版本控制

使用 Git LFS 追踪：

- `src/models/**/*.ckpt`；
- `src/data/**/*.bw`；
- `src/data/variants/*.vcf.gz`；
- `src/data/variants/*.vcf.gz.tbi`。

区域表、染色体长度、代码、PWM 和文档使用普通 Git。`.gitignore` 排除
`src/data/corigami_data/data/` 中下载或生成的大数据、`outputs/`、临时 VCF、FASTA
中间文件及 notebook 执行缓存。说明文件不受忽略规则影响。

本地环境当前没有 `git-lfs` 命令。实施时安装到用户可写位置，执行 LFS 初始化和属性
配置后再添加大文件。推送前确认这些文件在 Git 索引中是 LFS pointer，实际二进制没有
进入普通 Git object database。

## 来源记录与完整性

`docs/source-manifest.tsv` 扩展为同时覆盖代码和上传资源，至少包含类别、仓库路径、
原始路径、公开来源、用途、导入前 SHA-256 和仓库版本 SHA-256。对未修改的二进制，
两个哈希必须相同。README 用简明表格说明哪些内容已上传、哪些需下载、哪些由脚本
生成，并明确 dscNanoATAC 数据属于 GM12878。

已确认的关键二进制 SHA-256 为：

| 文件 | SHA-256 |
|---|---|
| standard checkpoint | `81c1379928adfbe0ec26f236a03347bf51a3ccecf1a261ef343f04f9e2fa0c55` |
| ATAC-only checkpoint | `d41c9ee236eeaeeaeb7bd49a516bcedb07620d830756068ecc7b83949892e599` |
| paternal dscNanoATAC | `6c8a0249e6b3097a0a0e6b5a0035cccb555a0a08c0622fb70140d8e010b21b52` |
| maternal dscNanoATAC | `4e7304569a43eea50c3c556cc201f4eced93e2eb7a14bc523c704ff8347ddd6a` |
| merged dscNanoATAC | `36cea84aeea3fb6d414534ef8363a8f2bcbe9fcbae329d2a331968a95a7938a9` |
| SNP region summary | `4820a69d48451a21bbf2c87e480a125e30b127e5f7e15fd3e9043c80570570fc` |
| chromosome sizes | `d525ee20551f34768f4017c7a779a3f3c7b947dacdea27838a5776508834b306` |

VCF 及索引在导入时计算并写入 manifest，不用未经验证的远端摘要替代本地文件哈希。

## 验证策略

实施完成后执行以下检查：

1. 用 `bash -n` 检查训练和 diploid DNA shell 脚本。
2. 用 Python 编译检查两个辅助 Python 文件和 Plan E CTCF 生成脚本。
3. 在依赖可用时对三个 Snakefile 执行 Snakemake dry-run；若集群环境缺少依赖，至少
   加载并验证规则展开、输入路径和输出路径。
4. 用 JSON 解析器检查三个 notebook，并比较修改前后的输出单元内容，确认未清空或
   重算历史输出。
5. 检查所有脚本中的资源路径均指向约定的仓库位置，且运行入口不含旧项目或软件目录
   的硬编码绝对路径。来源 manifest 中保留的绝对路径不计入此限制。
6. 对所有上传数据和模型重新计算 SHA-256，并与 manifest 对照。
7. 用 Git LFS 检查追踪列表和 pointer 内容；检查普通 Git 中不存在超过 GitHub 限制的
   二进制 blob。
8. 扫描常见凭证模式，确认 notebook 输出和脚本中没有意外提交 token 或密码。
9. 推送后通过 GitHub 元数据确认 `LuJiansen/AS-C.Origami` 为私人仓库，本地与远端
   `main` 指向同一提交，并确认 LFS 对象上传完成。

不把完整训练、全量预测、diploid DNA/CTCF 全基因组生成或 benchmark notebook 全量
重执行作为本次验收条件，因为这些步骤需要显著计算资源和未上传的外部 benchmark
输入。

## 完成标准

- 约定的代码、两个 checkpoint、三个 GM12878 dscNanoATAC BigWig、区域表、染色体
  长度和 phased VCF/index 均位于 `src/` 下的固定位置。
- 训练、预测、SNP density 和生成脚本使用仓库相对路径；Plan E merge 的未定义变量已
  修正。
- Zenodo、Illumina Platinum Genomes、集群源文件和 dscNanoATAC 的来源记录清楚。
- Notebook 历史输出保持不变，新增运行产物不进入 Git。
- 语法、路径、哈希、Git LFS、凭证扫描和 GitHub 私有性检查通过，私有远端与本地
  `main` 同步。
