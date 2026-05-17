# Promotion validation report

## Commands

```sh
moon test --target all
moon test
moon test src/layout/dot/order_pipeline_fixture_wbtest.mbt --target native --filter "plugins root/remincross mincross inputs match graphviz fixtures"
moon test src/render/svg/svg_test.mbt --target native --filter "render_svg keeps trapeziumlr node families as polygons"
```

## Relevant output

```text
parse_dot_file failed: refs/graphviz/doc/dotguide/graph1.dot ... No such file or directory
parse_dot_file failed: refs/graphviz/graphs/directed/clust.gv ... No such file or directory
missing snapshot input for case japanese
```

`git submodule status` shows the `refs/graphviz` submodule is not initialized locally:

```text
-a74b50c20fc624f46f72e24f981b261f6e5edf71 refs/graphviz
```

The strict-parity workflow also references `src/layout/dot/order_pipeline_fixture_wbtest.mbt`, but that file is absent from this checkout.

## Analysis

The broad test failures depend on fixture files from the uninitialized `refs/graphviz` submodule, which CI fetches with `submodules: recursive`. The missing strict-parity file appears to be a workflow/repository drift issue in this checkout rather than a MoonBit compiler promotion issue. The targeted `src/render/svg/svg_test.mbt` command fails for the same missing fixture data.
