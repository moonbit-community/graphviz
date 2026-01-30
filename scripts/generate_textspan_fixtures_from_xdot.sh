#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_path="${repo_root}/tests/fixtures/graphviz/textspan.jsonl"
xdot_dir="${repo_root}/tests/render/xdot"

if [ ! -d "$xdot_dir" ]; then
  echo "xdot snapshots not found at $xdot_dir" >&2
  exit 1
fi

python3 "$repo_root/scripts/generate_textspan_fixtures_from_xdot.py"
