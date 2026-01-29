#!/usr/bin/env bash
set -euo pipefail

DOT_BIN="${DOT_BIN:-dot}"
if [ -x "$DOT_BIN" ]; then
  :
elif command -v "$DOT_BIN" >/dev/null 2>&1; then
  :
else
  echo "dot CLI not found; set DOT_BIN or install Graphviz to generate font metrics" >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 not found; install Python to generate font metrics" >&2
  exit 1
fi

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
output_path="${repo_root}/src/layout/dot/font_metrics/font_metrics.generated.mbt"
export OUTPUT_PATH="${output_path}"

python3 - <<'PY'
import json
import os
import subprocess
import tempfile

fontname = "Times-Roman"
fontsize = 14.0

output_path = os.environ["OUTPUT_PATH"]

def escape_label(text: str) -> str:
    return text.replace("\\", "\\\\").replace('"', '\\"')

dot_bin = os.environ.get("DOT_BIN", "dot")

def dot_textspan(dot_source: str) -> list[dict]:
    with tempfile.NamedTemporaryFile(delete=False) as tmp:
        log_path = tmp.name
    env = os.environ.copy()
    env["MBT_CAPTURE_TEXTSPAN"] = log_path
    result = subprocess.run(
        [dot_bin, "-Tdot"],
        input=dot_source.encode("utf-8"),
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
        env=env,
    )
    if result.returncode != 0:
        raise RuntimeError(result.stderr.decode("utf-8", errors="ignore"))
    entries = []
    with open(log_path, "r", encoding="utf-8") as handle:
        for line in handle:
            line = line.strip()
            if not line:
                continue
            entries.append(json.loads(line))
    os.remove(log_path)
    if not entries:
        raise RuntimeError(
            "MBT_CAPTURE_TEXTSPAN produced no entries; ensure DOT_BIN includes the textspan patch"
        )
    return entries

def collect_text_widths(labels: list[tuple[str, str]]) -> dict[str, float]:
    lines = [
        "digraph metrics {",
        f'  node [shape=box, fontname="{fontname}", fontsize={fontsize}];',
    ]
    for name, label in labels:
        lines.append(f'  {name} [label="{escape_label(label)}"];')
    lines.append("}")
    entries = dot_textspan("\n".join(lines))
    wanted = {label for _, label in labels}
    by_text: dict[str, float] = {}
    for entry in entries:
        if entry.get("font") != fontname:
            continue
        if entry.get("size") != fontsize:
            continue
        if entry.get("flags") != 0:
            continue
        text = entry.get("text") or ""
        if text in wanted and text not in by_text:
            by_text[text] = float(entry.get("width", 0.0))
    widths: dict[str, float] = {}
    for name, label in labels:
        width = by_text.get(label)
        if width is None:
            print(f"warning: failed to measure {label!r}")
            continue
        widths[name] = width
    return widths

printable_codes = [code for code in range(128) if 32 <= code <= 126]
char_labels = [(f"c{code}", chr(code)) for code in printable_codes]
char_widths_pt = collect_text_widths(char_labels)

widths = []
for code in range(128):
    if code < 32 or code == 127:
        widths.append(-1.0)
        continue
    width_pt = char_widths_pt.get(f"c{code}")
    if width_pt is None:
        widths.append(-1.0)
        print(f"warning: failed to measure char {code} ({repr(chr(code))})")
    else:
        widths.append(width_pt / fontsize * 1000.0)

pair_labels = [
    (f"p{left}_{right}", chr(left) + chr(right))
    for left in printable_codes
    for right in printable_codes
]
pair_widths_pt = collect_text_widths(pair_labels)

space_ctx_labels = [
    (f"s{code}", "o " + chr(code) + "o")
    for code in printable_codes
]
space_ctx_widths_pt = collect_text_widths(space_ctx_labels)

kerning = []
for left in range(128):
  for right in range(128):
        if left < 32 or left == 127 or right < 32 or right == 127:
            kerning.append(0.0)
            continue
        left_width = widths[left]
        right_width = widths[right]
        if left_width <= 0.0 or right_width <= 0.0:
            kerning.append(0.0)
            continue
        pair_key = f"p{left}_{right}"
        pair_width_pt = pair_widths_pt.get(pair_key)
        if pair_width_pt is None:
            kerning.append(0.0)
            print(
                f"warning: failed to measure kerning {left},{right} ({chr(left)+chr(right)!r})"
            )
            continue
        pair_width_units = pair_width_pt / fontsize * 1000.0
        kerning.append(pair_width_units - left_width - right_width)

space_kerning = []
space_units = widths[ord(" ")]
o_units = widths[ord("o")]
for right in range(128):
    if right < 32 or right == 127:
        space_kerning.append(0.0)
        continue
    right_width = widths[right]
    if right_width <= 0.0:
        space_kerning.append(0.0)
        continue
    pair_key = f"s{right}"
    pair_width_pt = space_ctx_widths_pt.get(pair_key)
    if pair_width_pt is None:
        space_kerning.append(0.0)
        print(f"warning: failed to measure space kerning for {right} ({repr(chr(right))})")
        continue
    pair_width_units = pair_width_pt / fontsize * 1000.0
    k_right_o = kerning[right * 128 + ord("o")]
    space_kerning.append(
        pair_width_units - o_units - space_units - right_width - o_units - k_right_o
    )

with open(output_path, "w", encoding="ascii") as f:
    f.write("///|\n")
    f.write("pub const HAS_FONT_METRICS : Bool = true\n\n")
    f.write("///|\n")
    f.write("pub const HAS_FONT_KERNING : Bool = true\n\n")

    f.write("///|\n")
    f.write("pub const HAS_SPACE_KERNING : Bool = true\n\n")
    f.write("///|\n")
    f.write("pub let font_metrics : Array[Double] = [\n")
    for i, value in enumerate(widths):
        if i % 8 == 0:
            f.write("  ")
        if value < 0:
            text = "-1.0"
        else:
            text = repr(value)
        f.write(text)
        if i != len(widths) - 1:
            f.write(", ")
        if i % 8 == 7:
            f.write("\n")
    if len(widths) % 8 != 0:
        f.write("\n")
    f.write("]\n")

    f.write("\n///|\n")
    f.write("pub let font_kerning : Array[Double] = [\n")
    for i, value in enumerate(kerning):
        if i % 8 == 0:
            f.write("  ")
        text = repr(value)
        f.write(text)
        if i != len(kerning) - 1:
            f.write(", ")
        if i % 8 == 7:
            f.write("\n")
    if len(kerning) % 8 != 0:
        f.write("\n")
    f.write("]\n")

    f.write("\n///|\n")
    f.write("pub let font_space_kerning : Array[Double] = [\n")
    for i, value in enumerate(space_kerning):
        if i % 8 == 0:
            f.write("  ")
        text = repr(value)
        f.write(text)
        if i != len(space_kerning) - 1:
            f.write(", ")
        if i % 8 == 7:
            f.write("\n")
    if len(space_kerning) % 8 != 0:
        f.write("\n")
    f.write("]\n")
PY
