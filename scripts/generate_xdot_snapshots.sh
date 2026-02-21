#!/usr/bin/env bash
set -euo pipefail

dot_bin="${DOT_BIN:-dot}"
if ! command -v "${dot_bin}" >/dev/null 2>&1; then
  echo "dot CLI not found; install Graphviz or set DOT_BIN to generate xdot snapshots" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="${repo_root}/tests/render/xdot"

resolve_input_for_case() {
  local case_name="$1"
  local candidates=(
    "refs/graphviz/graphs/directed/${case_name}.gv"
    "tests/layout/dot/${case_name}.dot"
    "refs/graphviz/doc/dotguide/${case_name}.dot"
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

if [[ ! -d "${fixture_dir}" ]]; then
  echo "fixture dir not found: ${fixture_dir}" >&2
  exit 1
fi

mapfile -t fixtures < <(
  find "${fixture_dir}" -maxdepth 1 -type f -name "*.xdot" -exec basename {} \; |
    LC_ALL=C sort
)
if [[ ${#fixtures[@]} -eq 0 ]]; then
  echo "no xdot fixtures found under ${fixture_dir}" >&2
  exit 1
fi

for fixture in "${fixtures[@]}"; do
  case_name="${fixture%.xdot}"
  input_path="$(resolve_input_for_case "${case_name}")"
  output_path="${fixture_dir}/${fixture}"
  "${dot_bin}" -Txdot "${input_path}" -o "${output_path}"
  echo "wrote ${output_path#${repo_root}/}"
done
