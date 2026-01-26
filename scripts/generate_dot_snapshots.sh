#!/usr/bin/env bash
set -euo pipefail

if ! command -v dot >/dev/null 2>&1; then
  echo "dot CLI not found; install Graphviz to generate dot snapshots" >&2
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
  dot -Tdot "${input_path}" -o "${output_path}"
done
