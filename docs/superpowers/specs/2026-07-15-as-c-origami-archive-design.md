# AS-C.Origami 流程归档设计

## 目标

在 `analysis/AS-C.Origami` 中建立独立 Git 仓库，结构化归档 AS-C.Origami
训练、预测、SNP 密度计算和 benchmark 代码，并推送到 GitHub 私有仓库
`LuJiansen/AS-C.Origami`。

归档以实验可追溯性为首要原则：用户指定的 8 个源文件逐字节复制，保留
notebook 的现有输出，不改写硬编码路径、参数或执行逻辑。

## 内容范围

### 训练

- `training/corigami_train.sh`
- `training/corigami_train_atac_only.sh`

### 预测

- `prediction/run_top_pred.smk`
- `prediction/run_top_pred_planE.smk`
- `prediction/run_top_pred_planH.smk`

### SNP 密度

- `snp-density/SNP_density.ipynb`

### Benchmark

- `benchmarks/corigami_predict_benchmark_dip3d_planA_merge.ipynb`
- `benchmarks/corigami_predict_benchmark_planAEH.ipynb`

模型 checkpoint、输入数据、参考基因组、BigWig、预测矩阵、benchmark 中间结果和
未被用户明确指定的辅助 Python 脚本不纳入仓库。它们作为外部依赖记录在文档中。

## 仓库结构

```text
AS-C.Origami/
├── README.md
├── .gitignore
├── training/
├── prediction/
├── snp-density/
├── benchmarks/
└── docs/
    ├── workflow.md
    ├── dependencies.md
    ├── source-manifest.tsv
    └── superpowers/
        ├── specs/
        └── plans/
```

`README.md` 提供入口和目录导航；`workflow.md` 总结各阶段数据流；
`dependencies.md` 汇总软件、外部脚本、模型、参考数据和需按环境调整的路径；
`source-manifest.tsv` 记录每个归档文件的类别、仓库路径、原始绝对路径和
SHA-256。

## 流程关系

1. `SNP_density.ipynb` 生成或整理 SNP 密度结果，供预测流程选择高 SNP 密度窗口。
2. 两个训练脚本分别启动标准 C.Origami 与 ATAC-only 模型训练。
3. `run_top_pred.smk` 归档 Plan A 预测；`run_top_pred_planE.smk` 归档使用连续
   PWM CTCF 轨迹的 Plan E；`run_top_pred_planH.smk` 归档 ATAC-only Plan H。
4. Plan A merge benchmark notebook 比较 Plan A 预测与 Dip3D 参考；Plan A/E/H
   notebook 在共享窗口上比较三种方案，并保留现有图表和表格输出作为参考。

文档只描述现有流程，不声明所有外部依赖均已打包，也不承诺离开当前集群后可直接
运行。

## 原样归档与可追溯性

- 8 个指定文件不清空 notebook 输出，不格式化，不修改路径。
- 复制前后使用 SHA-256 比对；所有归档副本必须与源文件一致。
- source manifest 保留源文件绝对路径，明确当前集群中的来源。
- README 明确硬编码路径需在其他环境中调整，但不提供未经验证的重构版本。

## 验证

- 对 8 个文件执行 SHA-256 源/目标比对。
- 使用 `jq empty` 验证三个 notebook 是有效 JSON。
- 使用 `bash -n` 检查两个 shell 脚本语法。
- 检查仓库中不存在 checkpoint、预测矩阵、BigWig 或其他意外大文件，且无单文件
  达到 GitHub 100 MB 限制。
- 搜索常见 token、password、secret 和 API key 模式；绝对集群路径按设计保留。
- 检查 Git 工作区干净、提交包含预期文件。
- 推送后查询 GitHub 仓库元数据，确认仓库名为 `AS-C.Origami`、可见性为
  `PRIVATE`，且远端 `main` 指向本地提交。

Snakemake dry-run 和 notebook 全量重执行不属于本次验证范围，因为它们依赖未纳入
仓库的模型、参考数据、输入轨迹和特定 Conda/R 环境。

## 发布

仓库使用 `main` 分支，并通过 GitHub CLI 创建 `LuJiansen/AS-C.Origami` 私有仓库。
若同名仓库已存在，则先核验所有者与私有可见性，再添加远端并推送，不覆盖未知远端
历史。当前 GitHub CLI 凭证失效，实施阶段需要重新认证后才能完成创建和推送。

## 完成标准

- 目标目录具有上述结构，且只包含明确范围内的源代码、文档和 Git 元数据。
- 8 个归档文件与源文件哈希完全一致，notebook 输出得到保留。
- 文档能解释每个文件的用途、阶段关系、外部依赖和路径限制。
- 本地验证全部通过并形成提交。
- `LuJiansen/AS-C.Origami` 存在于 GitHub、为私有仓库，且 `main` 已同步。
