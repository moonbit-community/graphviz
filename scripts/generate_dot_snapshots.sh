#!/usr/bin/env bash
set -euo pipefail

dot_bin="${DOT_BIN:-dot}"
if ! command -v "${dot_bin}" >/dev/null 2>&1; then
  echo "dot CLI not found; install Graphviz or set DOT_BIN to generate dot snapshots" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

pairs=(
  "refs/graphviz/graphs/directed/grammar.gv tests/layout/dot/grammar.dot"
  "tests/layout/dot/compound.dot tests/layout/dot/compound.gv.dot"
  "refs/graphviz/graphs/directed/clust1.gv tests/layout/dot/clust1.gv.dot"
  "refs/graphviz/graphs/directed/clust2.gv tests/layout/dot/clust2.gv.dot"
  "refs/graphviz/graphs/directed/clust3.gv tests/layout/dot/clust3.gv.dot"
  "refs/graphviz/graphs/directed/clust4.gv tests/layout/dot/clust4.gv.dot"
  "refs/graphviz/graphs/directed/clust5.gv tests/layout/dot/clust5.gv.dot"
  "refs/graphviz/graphs/directed/try.gv tests/layout/dot/try.gv.dot"
  "refs/graphviz/graphs/directed/fsm.gv tests/layout/dot/fsm.gv.dot"
  "refs/graphviz/graphs/directed/dfa.gv tests/layout/dot/dfa.gv.dot"
  "refs/graphviz/graphs/directed/longflat.gv tests/layout/dot/longflat.gv.dot"
  "refs/graphviz/graphs/directed/states.gv tests/layout/dot/states.gv.dot"
  "refs/graphviz/graphs/directed/record2.gv tests/layout/dot/record2.gv.dot"
  "refs/graphviz/graphs/directed/structs.gv tests/layout/dot/structs.gv.dot"
  "refs/graphviz/graphs/directed/arr_none.gv tests/layout/dot/arr_none.gv.dot"
  "refs/graphviz/graphs/directed/table.gv tests/layout/dot/table.gv.dot"
  "refs/graphviz/graphs/directed/train11.gv tests/layout/dot/train11.gv.dot"
  "refs/graphviz/graphs/directed/tree.gv tests/layout/dot/tree.gv.dot"
  "refs/graphviz/graphs/directed/abstract.gv tests/layout/dot/abstract.gv.dot"
  "refs/graphviz/graphs/directed/arrows.gv tests/layout/dot/arrows.gv.dot"
  "refs/graphviz/graphs/directed/biological.gv tests/layout/dot/biological.gv.dot"
  "refs/graphviz/graphs/directed/ctext.gv tests/layout/dot/ctext.gv.dot"
  "refs/graphviz/graphs/directed/fig6.gv tests/layout/dot/fig6.gv.dot"
  "refs/graphviz/graphs/directed/hashtable.gv tests/layout/dot/hashtable.gv.dot"
  "refs/graphviz/graphs/directed/records.gv tests/layout/dot/records.gv.dot"
  "refs/graphviz/graphs/directed/switch.gv tests/layout/dot/switch.gv.dot"
  "refs/graphviz/graphs/directed/trapeziumlr.gv tests/layout/dot/trapeziumlr.gv.dot"
  "refs/graphviz/graphs/directed/triedds.gv tests/layout/dot/triedds.gv.dot"
  "refs/graphviz/graphs/directed/unix.gv tests/layout/dot/unix.gv.dot"
  "refs/graphviz/graphs/directed/viewfile.gv tests/layout/dot/viewfile.gv.dot"
  "refs/graphviz/graphs/directed/ldbxtried.gv tests/layout/dot/ldbxtried.gv.dot"
  "refs/graphviz/graphs/directed/proc3d.gv tests/layout/dot/proc3d.gv.dot"
  "refs/graphviz/graphs/directed/world.gv tests/layout/dot/world.gv.dot"
  "refs/graphviz/graphs/directed/pmpipe.gv tests/layout/dot/pmpipe.gv.dot"
  "refs/graphviz/graphs/directed/polypoly.gv tests/layout/dot/polypoly.gv.dot"
  "refs/graphviz/graphs/directed/alf.gv tests/layout/dot/alf.gv.dot"
  "refs/graphviz/graphs/directed/clust.gv tests/layout/dot/clust.gv.dot"
  "refs/graphviz/graphs/directed/jcctree.gv tests/layout/dot/jcctree.gv.dot"
  "refs/graphviz/graphs/directed/jsort.gv tests/layout/dot/jsort.gv.dot"
  "refs/graphviz/graphs/directed/shells.gv tests/layout/dot/shells.gv.dot"
  "refs/graphviz/graphs/directed/awilliams.gv tests/layout/dot/awilliams.gv.dot"
  "refs/graphviz/graphs/directed/crazy.gv tests/layout/dot/crazy.gv.dot"
  "refs/graphviz/graphs/directed/honda-tokoro.gv tests/layout/dot/honda-tokoro.gv.dot"
  "refs/graphviz/graphs/directed/KW91.gv tests/layout/dot/KW91.gv.dot"
  "refs/graphviz/graphs/directed/Latin1.gv tests/layout/dot/Latin1.gv.dot"
  "refs/graphviz/graphs/directed/mike.gv tests/layout/dot/mike.gv.dot"
  "refs/graphviz/graphs/directed/NaN.gv tests/layout/dot/NaN.gv.dot"
  "refs/graphviz/graphs/directed/nhg.gv tests/layout/dot/nhg.gv.dot"
  "refs/graphviz/graphs/directed/oldarrows.gv tests/layout/dot/oldarrows.gv.dot"
  "refs/graphviz/graphs/directed/pgram.gv tests/layout/dot/pgram.gv.dot"
  "refs/graphviz/graphs/directed/pm2way.gv tests/layout/dot/pm2way.gv.dot"
  "refs/graphviz/graphs/directed/psfonttest.gv tests/layout/dot/psfonttest.gv.dot"
  "refs/graphviz/graphs/directed/rowe.gv tests/layout/dot/rowe.gv.dot"
  "refs/graphviz/graphs/directed/sdh.gv tests/layout/dot/sdh.gv.dot"
  "refs/graphviz/graphs/directed/unix2.gv tests/layout/dot/unix2.gv.dot"
  "tests/layout/dot/edge_vnode_spacing.dot tests/layout/dot/edge_vnode_spacing.gv.dot"
  "tests/layout/dot/edge_label_spacing.dot tests/layout/dot/edge_label_spacing.gv.dot"
  "tests/layout/dot/complex.dot tests/layout/dot/complex.gv.dot"
)

for pair in "${pairs[@]}"; do
  read -r input output <<<"${pair}"
  input_path="${repo_root}/${input}"
  output_path="${repo_root}/${output}"
  if [[ ! -f "${input_path}" ]]; then
    echo "missing input: ${input}" >&2
    exit 1
  fi
  mkdir -p "$(dirname "${output_path}")"
  "${dot_bin}" -Tdot "${input_path}" -o "${output_path}"
done
