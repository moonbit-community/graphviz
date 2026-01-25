#!/usr/bin/env bash
set -euo pipefail

if ! command -v dot >/dev/null 2>&1; then
  echo "dot CLI not found; install Graphviz to generate svg snapshots" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

pairs=(
  "refs/graphviz/doc/dotguide/graph1.dot tests/render/svg/graph1.svg"
  "refs/graphviz/graphs/directed/arrows.gv tests/render/svg/arrows.svg"
  "refs/graphviz/graphs/directed/arr_none.gv tests/render/svg/arr_none.svg"
  "refs/graphviz/graphs/directed/records.gv tests/render/svg/records.svg"
  "refs/graphviz/graphs/directed/record2.gv tests/render/svg/record2.svg"
  "refs/graphviz/graphs/directed/clust.gv tests/render/svg/clust.svg"
  "refs/graphviz/graphs/directed/clust1.gv tests/render/svg/clust1.svg"
  "refs/graphviz/graphs/directed/clust2.gv tests/render/svg/clust2.svg"
  "refs/graphviz/graphs/directed/clust3.gv tests/render/svg/clust3.svg"
  "refs/graphviz/graphs/directed/clust4.gv tests/render/svg/clust4.svg"
  "refs/graphviz/graphs/directed/clust5.gv tests/render/svg/clust5.svg"
  "refs/graphviz/graphs/directed/ctext.gv tests/render/svg/ctext.svg"
  "refs/graphviz/graphs/directed/dfa.gv tests/render/svg/dfa.svg"
  "refs/graphviz/graphs/directed/fsm.gv tests/render/svg/fsm.svg"
  "refs/graphviz/graphs/directed/grammar.gv tests/render/svg/grammar.svg"
  "refs/graphviz/graphs/directed/longflat.gv tests/render/svg/longflat.svg"
  "refs/graphviz/graphs/directed/states.gv tests/render/svg/states.svg"
  "refs/graphviz/graphs/directed/structs.gv tests/render/svg/structs.svg"
  "refs/graphviz/graphs/directed/table.gv tests/render/svg/table.svg"
  "refs/graphviz/graphs/directed/train11.gv tests/render/svg/train11.svg"
  "refs/graphviz/graphs/directed/tree.gv tests/render/svg/tree.svg"
  "refs/graphviz/graphs/directed/try.gv tests/render/svg/try.svg"
  "tests/layout/dot/compound.dot tests/render/svg/compound.svg"
  "tests/layout/dot/complex.dot tests/render/svg/complex.svg"
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
  dot -Tsvg "${input_path}" -o "${output_path}"
done
