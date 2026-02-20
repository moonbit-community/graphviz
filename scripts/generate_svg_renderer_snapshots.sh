#!/usr/bin/env bash
set -euo pipefail

dot_bin="${DOT_BIN:-dot}"
if ! command -v "${dot_bin}" >/dev/null 2>&1; then
  echo "dot CLI not found; install Graphviz or set DOT_BIN to generate svg snapshots" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="${repo_root}/tests/render/svg_snapshot"

inputs=(
  "refs/graphviz/doc/dotguide/graph1.dot"
  "tests/layout/dot/compound.dot"
  "tests/layout/dot/complex.dot"
  "tests/layout/dot/edge_vnode_spacing.dot"
  "tests/layout/dot/edge_label_spacing.dot"
  "refs/graphviz/graphs/directed/grammar.gv"
  "refs/graphviz/graphs/directed/clust1.gv"
  "refs/graphviz/graphs/directed/clust2.gv"
  "refs/graphviz/graphs/directed/clust3.gv"
  "refs/graphviz/graphs/directed/clust4.gv"
  "refs/graphviz/graphs/directed/clust5.gv"
  "refs/graphviz/graphs/directed/try.gv"
  "refs/graphviz/graphs/directed/fsm.gv"
  "refs/graphviz/graphs/directed/dfa.gv"
  "refs/graphviz/graphs/directed/longflat.gv"
  "refs/graphviz/graphs/directed/states.gv"
  "refs/graphviz/graphs/directed/record2.gv"
  "refs/graphviz/graphs/directed/structs.gv"
  "refs/graphviz/graphs/directed/arr_none.gv"
  "refs/graphviz/graphs/directed/table.gv"
  "refs/graphviz/graphs/directed/train11.gv"
  "refs/graphviz/graphs/directed/tree.gv"
  "refs/graphviz/graphs/directed/abstract.gv"
  "refs/graphviz/graphs/directed/arrows.gv"
  "refs/graphviz/graphs/directed/biological.gv"
  "refs/graphviz/graphs/directed/ctext.gv"
  "refs/graphviz/graphs/directed/fig6.gv"
  "refs/graphviz/graphs/directed/hashtable.gv"
  "refs/graphviz/graphs/directed/records.gv"
  "refs/graphviz/graphs/directed/switch.gv"
  "refs/graphviz/graphs/directed/trapeziumlr.gv"
  "refs/graphviz/graphs/directed/triedds.gv"
  "refs/graphviz/graphs/directed/unix.gv"
  "refs/graphviz/graphs/directed/viewfile.gv"
  "refs/graphviz/graphs/directed/ldbxtried.gv"
  "refs/graphviz/graphs/directed/proc3d.gv"
  "refs/graphviz/graphs/directed/world.gv"
  "refs/graphviz/graphs/directed/pmpipe.gv"
  "refs/graphviz/graphs/directed/polypoly.gv"
  "refs/graphviz/graphs/directed/alf.gv"
  "refs/graphviz/graphs/directed/clust.gv"
  "refs/graphviz/graphs/directed/japanese.gv"
  "refs/graphviz/graphs/directed/jcctree.gv"
  "refs/graphviz/graphs/directed/jsort.gv"
  "refs/graphviz/graphs/directed/shells.gv"
  "refs/graphviz/graphs/directed/awilliams.gv"
  "refs/graphviz/graphs/directed/crazy.gv"
  "refs/graphviz/graphs/directed/honda-tokoro.gv"
  "refs/graphviz/graphs/directed/KW91.gv"
  "refs/graphviz/graphs/directed/Latin1.gv"
  "refs/graphviz/graphs/directed/mike.gv"
  "refs/graphviz/graphs/directed/NaN.gv"
  "refs/graphviz/graphs/directed/nhg.gv"
  "refs/graphviz/graphs/directed/oldarrows.gv"
  "refs/graphviz/graphs/directed/pgram.gv"
  "refs/graphviz/graphs/directed/pm2way.gv"
  "refs/graphviz/graphs/directed/psfonttest.gv"
  "refs/graphviz/graphs/directed/russian.gv"
  "refs/graphviz/graphs/directed/rowe.gv"
  "refs/graphviz/graphs/directed/sdh.gv"
  "refs/graphviz/graphs/directed/unix2.gv"
)

mkdir -p "${fixture_dir}"

for input in "${inputs[@]}"; do
  input_path="${repo_root}/${input}"
  if [[ ! -f "${input_path}" ]]; then
    echo "missing input: ${input}" >&2
    exit 1
  fi

  name=$(basename "${input}")
  name="${name%.gv}"
  name="${name%.dot}"
  output_path="${fixture_dir}/${name}.svg"

  "${dot_bin}" -Tsvg "${input_path}" -o "${output_path}"
  echo "wrote ${output_path#${repo_root}/}"
done
