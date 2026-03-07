---
name: dot-layout-refactor-guardrails
description: Refactor the `layout/dot` code with maintainability-first guardrails while preserving strict Graphviz parity. Use when reorganizing files/functions, extracting subpackages, renaming stage-related files, or reducing wrapper-heavy code in dot layout pipelines (especially rank/order/position stages).
---

# Dot Layout Refactor Guardrails

## Apply this workflow

1. Align refactor scope with one cohesive responsibility (for example: rank assignment entry, clustered rank solve, C5 remincross pass composition).
2. Prefer fewer cohesive files over excessive micro-splitting; merge items with the same responsibility back into one focused file.
3. Prioritize high-value structural refactors (subpackage extraction, stage-boundary cleanup, wrapper reduction) over naming-only churn.
4. Rename files by meaningful responsibility or stage role; remove redundant prefixes/suffixes (`layout_pipeline_`, verbose `stage_x_phase_y`, `_helpers`) unless needed for disambiguation.
5. Eliminate thin forwarding functions when they add no behavior; either inline call sites or move the real entry into the target subpackage.
6. Do not inline solely because a function has one caller; inline only when it clearly improves readability/maintainability.
7. Extract shared helpers only when the abstraction has clear domain meaning (for example: “build raw label ports”, “assemble routing precompute input”) or removes real divergence risk; do not extract helpers that merely wrap trivial `match`/`if` syntax.
8. When a subpackage extraction leaves only an outer entry wrapper, move that entry into the subpackage and update call sites directly.
9. Stage-internal orchestration may live inside the owning subpackage; keep only cross-stage boundary orchestration in the root `dot` package.
10. If a dot-root stage is left with only thin cross-stage boundary wiring, merge that boundary logic into `layout.mbt` instead of preserving a wrapper-heavy `stage_x.mbt` file.
11. Avoid package aliasing unless required by conflict; keep imports and call paths straightforward.
12. If a dot-root stage still owns several orchestration-only phase files before extraction, merge them into one focused stage file (for example `stage_c.mbt`, `stage_d.mbt`) until the package boundary is ready.

## Preserve behavior and parity

1. Keep Graphviz-parity comments and ordering-sensitive logic intact during moves.
2. Keep refactor commits behavior-preserving; separate functional changes from structural changes.
3. Run focused checks after each logical step (`moon check`, targeted tests) before broader validation.
4. Prefer file-by-file migration for large moves; validate each moved file (or small batch) before continuing.
5. Before any commit, run `scripts/run_local_guard.sh` and require full pass, unless the repository explicitly documents a different mandatory guard workflow.
6. Commit and push immediately after a no-regression milestone.
7. When repository policy allows post-commit guard execution, you may pipeline long validations by committing a locally verified slice before the full guard finishes and preparing the next slice while it runs; if the guard fails, stash or shelve later WIP, return to the committed slice, fix it, rerun the guard, then resume. Repository-specific guard rules still take precedence.
8. When repository policy and local tooling allow parallel development, you may use temporary git worktrees to isolate independent refactor slices or let one worktree validate while another continues implementation. Keep write scopes disjoint, avoid overlapping edits across live worktrees, and remove temporary worktrees after merge or abandonment.
9. If parity/alignment regresses after a move, review the refactor diff first to identify root cause before writing fixes.

## Keep naming and structure consistent

1. Group stage-related items by algorithm phase and responsibility, not by temporary migration patterns.
2. Keep public APIs minimal; keep internal helpers private to their owning package.
3. Prefer explicit responsibility names (`cluster_pipeline`, `base_solve`, `rank_group`) over generic names (`misc`, `helper`, `temp`).
4. Avoid duplicate implementations across packages; if dependency direction blocks reuse, pass explicit callbacks and plan a later shared extraction.
5. When a tree-heavy refactor is blocked because a root public type owns public methods (for example `DotLayoutGraph::apply`), do not force a foreign-type alias move; keep the public root type stable and plan a separate internal/shared tree-type extraction before moving the tree algorithms.
6. Keep same-responsibility items together; avoid over-splitting into scattered micro-files.
7. When tree-heavy root algorithms are blocked on recursive `DotLayoutGraph`, introduce an internal shared layout-tree type plus root bridge conversions, then migrate one tree-heavy file at a time into the owning subpackage; validate the pilot move before expanding the pattern.
8. When encountering legacy trace/debug scaffolding during refactor, clean it opportunistically but keep refactor scope as the primary goal.

## Follow-up checklist per refactor slice

1. Confirm no redundant wrapper-only layer remains.
2. Confirm file names reflect real responsibilities.
3. Confirm targeted tests pass.
4. Confirm `scripts/run_local_guard.sh` passes.
5. Confirm commit message explains the structural intent.
