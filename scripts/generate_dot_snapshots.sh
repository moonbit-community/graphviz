#!/usr/bin/env bash
set -euo pipefail

dot_bin="${DOT_BIN:-dot}"
if ! command -v "${dot_bin}" >/dev/null 2>&1; then
  echo "dot CLI not found; install Graphviz or set DOT_BIN to generate dot snapshots" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="${repo_root}/tests/layout/dot"
manifest_path="${fixture_dir}/cases.txt"

resolve_input_for_case() {
  local case_name="$1"
  local candidates=(
    "refs/graphviz/graphs/directed/${case_name}.gv"
    "refs/graphviz/graphs/undirected/${case_name}.gv"
    "tests/layout/dot/${case_name}.dot"
    "refs/graphviz/doc/dotguide/${case_name}.dot"
    "refs/graphviz/doc/infosrc/${case_name}.dot"
    "refs/graphviz/doc/infosrc/${case_name}.gv"
    "refs/graphviz/doc/neato/${case_name}.dot"
    "refs/graphviz/contrib/prune/${case_name}.gv"
    "refs/graphviz/contrib/dirgraph/${case_name}.dot"
    "refs/graphviz/contrib/java-dot/${case_name}.dot"
    "refs/graphviz/tests/${case_name}.dot"
    "refs/graphviz/tests/graphs/${case_name}.gv"
    "refs/graphviz/tests/share/${case_name}.gv"
    "refs/graphviz/tests/windows/${case_name}.gv"
    "refs/graphviz/tests/regression_tests/${case_name}.gv"
    "refs/graphviz/tests/regression_tests/shapes/reference/${case_name}.gv"
    "refs/graphviz/tests/linux.x86/${case_name}.gv"
    "refs/graphviz/tests/nshare/${case_name}.gv"
    "refs/graphviz/tests/linux.i386/${case_name}.gv"
    "refs/graphviz/tests/macosx/${case_name}.gv"
  )
  local rel
  for rel in "${candidates[@]}"; do
    if [[ -f "${repo_root}/${rel}" ]]; then
      echo "${repo_root}/${rel}"
      return 0
    fi
  done
  echo "missing input for fixture case: ${case_name}" >&2
  return 1
}

fixture_path_for_case() {
  local case_name="$1"
  if [[ "${case_name}" == "grammar" ]]; then
    echo "${fixture_dir}/grammar.dot"
  else
    echo "${fixture_dir}/${case_name}.gv.dot"
  fi
}

if [[ ! -f "${manifest_path}" ]]; then
  echo "case manifest not found: ${manifest_path}" >&2
  exit 1
fi

case_names=()
while IFS= read -r case_name; do
  case_names+=("${case_name}")
done < <(
  sed -e "s/[[:space:]]*$//" \
      -e "/^[[:space:]]*#/d" \
      -e "/^[[:space:]]*$/d" \
      "${manifest_path}"
)

if [[ ${#case_names[@]} -eq 0 ]]; then
  echo "no dot cases listed in ${manifest_path}" >&2
  exit 1
fi

for case_name in "${case_names[@]}"; do
  input_path="$(resolve_input_for_case "${case_name}")"
  output_path="$(fixture_path_for_case "${case_name}")"
  mkdir -p "$(dirname "${output_path}")"
  "${dot_bin}" -Tdot "${input_path}" -o "${output_path}"
  echo "wrote ${output_path#${repo_root}/}"
done
