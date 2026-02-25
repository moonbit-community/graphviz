#!/usr/bin/env bash
set -euo pipefail

dot_bin="${DOT_BIN:-dot}"
if ! command -v "${dot_bin}" >/dev/null 2>&1; then
  echo "dot CLI not found; install Graphviz or set DOT_BIN to generate svg snapshots" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
fixture_dir="${repo_root}/tests/render/svg"
manifest_path="${fixture_dir}/cases.txt"

resolve_input_for_case() {
  local case_name="$1"
  python3 "${repo_root}/scripts/snapshot_inputs.py" --repo-root "${repo_root}" --case "${case_name}"
}

if [[ ! -d "${fixture_dir}" ]]; then
  echo "fixture dir not found: ${fixture_dir}" >&2
  exit 1
fi

if [[ ! -f "${manifest_path}" ]]; then
  echo "case manifest not found: ${manifest_path}" >&2
  exit 1
fi

case_names=()
while IFS= read -r case_name; do
  case_names+=("${case_name}")
done < <(
  sed -e 's/[[:space:]]*$//' \
      -e '/^[[:space:]]*#/d' \
      -e '/^[[:space:]]*$/d' \
      "${manifest_path}"
)
if [[ ${#case_names[@]} -eq 0 ]]; then
  echo "no svg cases listed in ${manifest_path}" >&2
  exit 1
fi

for case_name in "${case_names[@]}"; do
  fixture="${case_name}.svg"
  input_path="$(resolve_input_for_case "${case_name}")"
  output_path="${fixture_dir}/${fixture}"
  "${dot_bin}" -Tsvg "${input_path}" -o "${output_path}"
  echo "wrote ${output_path#${repo_root}/}"
done
