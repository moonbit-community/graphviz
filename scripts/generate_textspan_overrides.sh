#!/usr/bin/env bash
# Copyright (c) 2026 International Digital Economy Academy
# This program is made available under the terms of the Eclipse Public License 2.0.
# SPDX-License-Identifier: EPL-2.0


set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
input_path="${repo_root}/src/layout/dot/font_metrics/textspan_overrides.jsonl"
output_path="${repo_root}/src/layout/dot/font_metrics/textspan_overrides.generated.mbt"

if [ ! -f "$input_path" ]; then
  echo "textspan fixtures not found at $input_path" >&2
  exit 1
fi

export INPUT_PATH="$input_path"
export OUTPUT_PATH="$output_path"

python3 - <<'PY'
import json
import os

input_path = os.environ["INPUT_PATH"] if "INPUT_PATH" in os.environ else "src/layout/dot/font_metrics/textspan_overrides.jsonl"
output_path = os.environ["OUTPUT_PATH"] if "OUTPUT_PATH" in os.environ else "src/layout/dot/font_metrics/textspan_overrides.generated.mbt"

entries = {}
with open(input_path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        data = json.loads(line)
        key = (data["font"], float(data["size"]), data["text"])
        value = (
            float(data["width"]),
            float(data["height"]),
            float(data["yoffset_layout"]),
            float(data["yoffset_centerline"]),
        )
        entries[key] = value

def sort_key(item):
    (font, size, text) = item[0]
    return (font, size, text)

def fmt_float(value: float) -> str:
    text = repr(value)
    if text.endswith(".0"):
        return text
    return text

ordered_entries = sorted(entries.items(), key=sort_key)
# Bound each top-level segment even after moon fmt expands long tuples.
chunk_size = 512
chunk_count = (len(ordered_entries) + chunk_size - 1) // chunk_size
entry_type = "Array[(String, Double, String, Double, Double, Double, Double)]"

with open(output_path, "w", encoding="ascii") as out:
    out.write("///|\n")
    out.write("/// Overrides captured from Graphviz textspan fixtures.\n")
    out.write("/// Regenerate with: bash scripts/generate_textspan_overrides.sh\n")
    out.write(f"pub let textspan_overrides_data : {entry_type} = [\n")
    for chunk in range(chunk_count):
        out.write(f"  ..textspan_overrides_chunk_{chunk}(),\n")
    out.write("]\n")
    for index, ((font, size, text), (width, height, yoffset_layout, yoffset_centerline)) in enumerate(ordered_entries):
        if index % chunk_size == 0:
            out.write(f"\n///|\nfn textspan_overrides_chunk_{index // chunk_size}() -> {entry_type} {{\n[\n")
        out.write("  (")
        out.write(json.dumps(font))
        out.write(", ")
        out.write(fmt_float(size))
        out.write(", ")
        out.write(json.dumps(text))
        out.write(", ")
        out.write(fmt_float(width))
        out.write(", ")
        out.write(fmt_float(height))
        out.write(", ")
        out.write(fmt_float(yoffset_layout))
        out.write(", ")
        out.write(fmt_float(yoffset_centerline))
        out.write("),\n")
        if (index + 1) % chunk_size == 0 or index + 1 == len(ordered_entries):
            out.write("]\n}\n")
PY

moon fmt "$output_path"
