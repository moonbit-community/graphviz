#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GRAPHVIZ_DIR="$ROOT/refs/graphviz"
PATCH_FILE="$ROOT/tools/graphviz-capture/patches/rank.patch"
BUILD_DIR="$GRAPHVIZ_DIR/build"
OUT_DIR="$ROOT/tests/fixtures/graphviz"
OUT_FILE="$OUT_DIR/rank.jsonl"
TMP_FILE="$OUT_DIR/rank.jsonl.tmp"

if [[ ! -d "$GRAPHVIZ_DIR" ]]; then
  echo "refs/graphviz is missing; place Graphviz source at $GRAPHVIZ_DIR" >&2
  exit 1
fi

if [[ ! -f "$PATCH_FILE" ]]; then
  echo "Missing patch file: $PATCH_FILE" >&2
  exit 1
fi

if ! command -v cmake >/dev/null 2>&1; then
  echo "cmake is required to build refs/graphviz" >&2
  exit 1
fi

if ! command -v patch >/dev/null 2>&1; then
  echo "patch is required to apply Graphviz capture patches" >&2
  exit 1
fi

if command -v rg >/dev/null 2>&1; then
  HAS_MARKER=$(rg -q "MBT_CAPTURE_RANK" "$GRAPHVIZ_DIR/lib/common/ns.c" && echo yes || echo no)
else
  HAS_MARKER=$(grep -q "MBT_CAPTURE_RANK" "$GRAPHVIZ_DIR/lib/common/ns.c" && echo yes || echo no)
fi

if [[ "$HAS_MARKER" != "yes" ]]; then
  patch -p1 -d "$GRAPHVIZ_DIR" < "$PATCH_FILE"
fi

BISON_BIN=""
if [[ -x "/opt/homebrew/opt/bison/bin/bison" ]]; then
  BISON_BIN="/opt/homebrew/opt/bison/bin/bison"
fi

if [[ ! -f "$BUILD_DIR/Makefile" ]]; then
  CMAKE_ARGS=(-DGRAPHVIZ_CLI=ON)
  if [[ -n "$BISON_BIN" ]]; then
    CMAKE_ARGS+=(-DBISON_EXECUTABLE="$BISON_BIN")
  fi
  cmake -S "$GRAPHVIZ_DIR" -B "$BUILD_DIR" "${CMAKE_ARGS[@]}"
fi

cmake --build "$BUILD_DIR" --target dot_builtins

if [[ -x "$BUILD_DIR/cmd/dot/dot_builtins" ]]; then
  DOT_BIN="$BUILD_DIR/cmd/dot/dot_builtins"
elif [[ -x "$BUILD_DIR/cmd/dot/dot" ]]; then
  DOT_BIN="$BUILD_DIR/cmd/dot/dot"
elif [[ -x "$BUILD_DIR/bin/dot" ]]; then
  DOT_BIN="$BUILD_DIR/bin/dot"
else
  echo "dot binary not found in $BUILD_DIR" >&2
  exit 1
fi

mkdir -p "$OUT_DIR"
: > "$TMP_FILE"

# Use only source .dot inputs; .gv.dot snapshots include bare attrs that Graphviz won't parse.
for input in "$ROOT"/tests/layout/dot/*.dot; do
  if [[ "$input" == *.gv.dot ]]; then
    continue
  fi
  MBT_CAPTURE_RANK="$TMP_FILE" "$DOT_BIN" -Txdot "$input" >/dev/null
done

# Keep only the integrated feasible-tree / pre-balance / final-rank cases that
# still provide signal beyond the owner-local network_simplex algorithm tests.
python3 - "$TMP_FILE" "$OUT_FILE" <<'PY'
import json
import sys
from pathlib import Path

src_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
keep_cases = {
    (16, 0, 18, 20, 17),
    (17, 2, 116, 261, 115),
    (4, 2, 9, 12, 8),
    (2, 2, 10, 11, 9),
    (2, 2, 37, 48, 36),
    (1, 1, 43, 42, 42),
    (2, 2, 85, 117, 84),
    (1, 1, 47, 68, 46),
    (2, 2, 203, 306, 202),
}
pending_lines = []
input_key = None
tree_edges = None
with src_path.open() as src, out_path.open('w') as out:
    for line in src:
        if not line.strip():
            continue
        obj = json.loads(line)
        event = obj['event']
        if event == 'simplex_input':
            pending_lines = [line]
            input_key = (obj['case'], obj['balance'], len(obj['nodes']), len(obj['edges']))
            tree_edges = None
        elif event == 'simplex_tree':
            pending_lines.append(line)
            tree_edges = len(obj['edges'])
        elif event == 'simplex_pre_balance':
            pending_lines.append(line)
        elif event == 'simplex_output':
            pending_lines.append(line)
            full_key = None if input_key is None else (*input_key, tree_edges)
            if full_key in keep_cases:
                for pending_line in pending_lines:
                    out.write(pending_line)
            pending_lines = []
            input_key = None
            tree_edges = None
        else:
            # Drop acyclic trace events. The fixture replay only consumes simplex
            # input/tree/pre_balance/output blocks.
            continue
PY
rm -f "$TMP_FILE"

echo "Wrote $OUT_FILE"
