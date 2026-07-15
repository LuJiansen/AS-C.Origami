# README Workflow Documentation Design

## Goal

Extend the English README so a new user can understand what AS-C.Origami does,
how Plans A, E, and H differ, which plan is recommended, and where to obtain the
C.Origami software environment before running the repository workflows.

## Scope

The change is documentation-only. It will:

- add the supplied workflow images to `docs/images/` without altering them;
- add an overview of AS-C.Origami near the beginning of the README;
- add a concise comparison of the three prediction plans;
- identify Plan A (`Default`) as the recommended workflow;
- link to the upstream C.Origami installation instructions; and
- preserve the existing repository layout, data provenance, generation, training,
  prediction, and benchmark instructions.

No workflow code, model, data file, notebook output, or runtime path will change.

## README Structure

The README will retain its title and opening repository summary, followed by two
new sections before `Repository layout`:

1. `Overview` will explain that AS-C.Origami applies allele-specific ATAC signals
   derived with dscNanoATAC to the C.Origami model to predict allele-specific
   chromatin conformation. It will link the first mention of C.Origami to
   <https://github.com/tanjimin/C.Origami> and display
   `docs/images/AS-COrigami_workflow.png`.
2. `Prediction plans` will display
   `docs/images/plans_benchmark_workflow.png`, introduce the three aliases, and
   compare their prediction inputs and models in a Markdown table.

An `Environment setup` section will be placed before data download and execution
instructions. It will direct users to follow the upstream C.Origami repository's
environment setup steps first, then note the repository-specific dependencies
documented in `docs/dependencies.md`.

## Plan Definitions

The README comparison will use these exact mappings:

| Plan | Alias | Prediction inputs | Model |
|---|---|---|---|
| Plan A | Default | Bulk DNA, allele-specific dscNanoATAC, and bulk CTCF | Standard C.Origami |
| Plan E | All-hap. | Haplotype DNA, allele-specific dscNanoATAC, and allele-specific CTCF | Standard C.Origami |
| Plan H | No-CTCF | Haplotype DNA and allele-specific dscNanoATAC; no CTCF input | ATAC-only C.Origami |

Plan A will be labeled as the default and recommended starting workflow. The text
will stay descriptive and will not claim a performance advantage that is not
established by the repository evidence.

## Image Handling

The supplied files currently located beside the repository will be copied with
their filenames unchanged:

- `AS-COrigami_workflow.png` -> `docs/images/AS-COrigami_workflow.png`
- `plans_benchmark_workflow.png` -> `docs/images/plans_benchmark_workflow.png`

They are small PNG documentation assets and will be stored as normal Git files,
not Git LFS objects. Their source bytes and SHA-256 hashes will remain unchanged.

## Verification

Verification will confirm that:

- both README image references resolve to committed files;
- the copied image hashes match the supplied originals;
- all Plan A/E/H aliases and input definitions are present and consistent with
  the Snakefiles;
- the upstream C.Origami URL appears in the environment guidance;
- the existing 11 repository contract tests still pass; and
- the final Git diff contains only the approved documentation and image changes.
