#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
input_path="${repo_root}/tests/fixtures/graphviz/textspan.jsonl"
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

input_path = os.environ["INPUT_PATH"] if "INPUT_PATH" in os.environ else "tests/fixtures/graphviz/textspan.jsonl"
output_path = os.environ["OUTPUT_PATH"] if "OUTPUT_PATH" in os.environ else "src/layout/dot/font_metrics/textspan_overrides.generated.mbt"

entries = {}
with open(input_path, "r", encoding="utf-8") as handle:
    for line in handle:
        line = line.strip()
        if not line:
            continue
        data = json.loads(line)
        key = (data["font"], float(data["size"]), data["text"])
        value = (float(data["width"]), float(data["height"]))
        entries[key] = value

def sort_key(item):
    (font, size, text) = item[0]
    return (font, size, text)

def fmt_float(value: float) -> str:
    text = repr(value)
    if text.endswith(".0"):
        return text
    return text

with open(output_path, "w", encoding="ascii") as out:
    out.write("///|\n")
    out.write("/// Overrides captured from Graphviz textspan fixtures.\n")
    out.write("/// Regenerate with: bash scripts/generate_textspan_overrides.sh\n")
    out.write("pub let textspan_overrides_data : Array[(String, Double, String, Double, Double)] = [\n")
    for (font, size, text), (width, height) in sorted(entries.items(), key=sort_key):
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
        out.write("),\n")
    out.write("]\n")
PY
