#!/usr/bin/env bash
# Copyright (c) 2026 International Digital Economy Academy
# This program is made available under the terms of the Eclipse Public License 2.0.
# SPDX-License-Identifier: EPL-2.0


set -euo pipefail

if [[ -z "${DOT_BIN:-}" ]]; then
  echo "set DOT_BIN to an external Graphviz 14.1.1 dot binary" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
dot_bin="$("${repo_root}/scripts/require_graphviz_14_1_1.sh" "${DOT_BIN}")"
fixture_dir="${repo_root}/tests/render/xdot"
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
  echo "no xdot cases listed in ${manifest_path}" >&2
  exit 1
fi

for case_name in "${case_names[@]}"; do
  fixture="${case_name}.xdot"
  input_path="$(resolve_input_for_case "${case_name}")"
  output_path="${fixture_dir}/${fixture}"
  "${dot_bin}" -Txdot "${input_path}" > "${output_path}"
  echo "wrote ${output_path#${repo_root}/}"
done
