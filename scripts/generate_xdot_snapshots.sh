#!/usr/bin/env bash
set -euo pipefail

dot_bin="${DOT_BIN:-dot}"
if ! command -v "${dot_bin}" >/dev/null 2>&1; then
  echo "dot CLI not found; install Graphviz or set DOT_BIN to generate xdot snapshots" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

pairs=(
  "refs/graphviz/doc/dotguide/graph1.dot tests/render/xdot/graph1.xdot"
  "refs/graphviz/graphs/directed/arr_none.gv tests/render/xdot/arr_none.xdot"
  "refs/graphviz/graphs/directed/arrows.gv tests/render/xdot/arrows.xdot"
  "refs/graphviz/graphs/directed/clust.gv tests/render/xdot/clust.xdot"
  "refs/graphviz/graphs/directed/clust1.gv tests/render/xdot/clust1.xdot"
  "refs/graphviz/graphs/directed/clust2.gv tests/render/xdot/clust2.xdot"
  "refs/graphviz/graphs/directed/clust3.gv tests/render/xdot/clust3.xdot"
  "refs/graphviz/graphs/directed/clust4.gv tests/render/xdot/clust4.xdot"
  "refs/graphviz/graphs/directed/clust5.gv tests/render/xdot/clust5.xdot"
  "refs/graphviz/graphs/directed/records.gv tests/render/xdot/records.xdot"
  "refs/graphviz/graphs/directed/record2.gv tests/render/xdot/record2.xdot"
  "refs/graphviz/graphs/directed/ctext.gv tests/render/xdot/ctext.xdot"
  "refs/graphviz/graphs/directed/dfa.gv tests/render/xdot/dfa.xdot"
  "refs/graphviz/graphs/directed/fig6.gv tests/render/xdot/fig6.xdot"
  "refs/graphviz/graphs/directed/fsm.gv tests/render/xdot/fsm.xdot"
  "refs/graphviz/graphs/directed/longflat.gv tests/render/xdot/longflat.xdot"
  "refs/graphviz/graphs/directed/states.gv tests/render/xdot/states.xdot"
  "refs/graphviz/graphs/directed/structs.gv tests/render/xdot/structs.xdot"
  "tests/layout/dot/compound.dot tests/render/xdot/compound.xdot"
  "tests/layout/dot/complex.dot tests/render/xdot/complex.xdot"
  "refs/graphviz/graphs/directed/table.gv tests/render/xdot/table.xdot"
  "refs/graphviz/graphs/directed/train11.gv tests/render/xdot/train11.xdot"
  "refs/graphviz/graphs/directed/tree.gv tests/render/xdot/tree.xdot"
  "refs/graphviz/graphs/directed/try.gv tests/render/xdot/try.xdot"
  "refs/graphviz/graphs/directed/grammar.gv tests/render/xdot/grammar.xdot"
  "refs/graphviz/graphs/directed/abstract.gv tests/render/xdot/abstract.xdot"
  "refs/graphviz/graphs/directed/switch.gv tests/render/xdot/switch.xdot"
  "refs/graphviz/graphs/directed/pmpipe.gv tests/render/xdot/pmpipe.xdot"
  "refs/graphviz/graphs/directed/pm2way.gv tests/render/xdot/pm2way.xdot"
  "refs/graphviz/graphs/directed/viewfile.gv tests/render/xdot/viewfile.xdot"
  "refs/graphviz/graphs/directed/triedds.gv tests/render/xdot/triedds.xdot"
  "refs/graphviz/graphs/directed/hashtable.gv tests/render/xdot/hashtable.xdot"
  "refs/graphviz/graphs/directed/oldarrows.gv tests/render/xdot/oldarrows.xdot"
  "refs/graphviz/graphs/directed/unix.gv tests/render/xdot/unix.xdot"
  "refs/graphviz/graphs/directed/world.gv tests/render/xdot/world.xdot"
  "refs/graphviz/graphs/directed/japanese.gv tests/render/xdot/japanese.xdot"
  "refs/graphviz/graphs/directed/russian.gv tests/render/xdot/russian.xdot"
  "refs/graphviz/graphs/directed/unix2.gv tests/render/xdot/unix2.xdot"
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
  "${dot_bin}" -Txdot "${input_path}" -o "${output_path}"
done
