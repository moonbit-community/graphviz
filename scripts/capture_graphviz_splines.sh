#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GRAPHVIZ_DIR="$ROOT/refs/graphviz"
PATCH_FILE="$ROOT/tools/graphviz-capture/patches/splines.patch"
BUILD_DIR="$GRAPHVIZ_DIR/build"
OUT_DIR="$ROOT/tests/fixtures/graphviz"
OUT_FILE="$OUT_DIR/splines.jsonl"
TMP_FILE="$OUT_DIR/splines.jsonl.tmp"

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
  HAS_MARKER=$(rg -q "MBT_CAPTURE_SPLINES" "$GRAPHVIZ_DIR/lib/common/routespl.c" && echo yes || echo no)
else
  HAS_MARKER=$(grep -q "MBT_CAPTURE_SPLINES" "$GRAPHVIZ_DIR/lib/common/routespl.c" && echo yes || echo no)
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
  MBT_CAPTURE_SPLINES="$TMP_FILE" "$DOT_BIN" -Txdot "$input" >/dev/null
done

# Keep only the integrated spline/pathplan replay cases that still provide
# signal beyond the owner-local pathplan, routesplines, and edge_spline tests.
python3 - "$TMP_FILE" "$OUT_FILE" <<'PY'
import json
import sys
from pathlib import Path

src_path = Path(sys.argv[1])
out_path = Path(sys.argv[2])
keep_counts = {
    ("", "accel", "tunnel_egress"): 1,
    ("", "C1N1", "C2N1"): 1,
    ("", "foo_agent", "zzz_worker"): 1,
    ("", "zzz_worker", "zzz"): 1,
    ("", "z_shapeshifter", "machsrv_xprot_gen"): 1,
    ("", "arbiter_vadam", "other_xprot"): 1,
    ("clust1", "a3", "a0"): 1,
    ("states", "empty", "full"): 1,
}
seen_counts = {key: 0 for key in keep_counts}
keep_case = False
current_key = None
with src_path.open() as src, out_path.open("w") as out:
    for line in src:
        if not line.strip():
            continue
        obj = json.loads(line)
        event = obj["event"]
        if event == "spline_input":
            current_key = (obj.get("graph") or "", obj["tail"], obj["head"])
            keep_case = current_key in keep_counts and seen_counts[current_key] < keep_counts[current_key]
            if keep_case:
                seen_counts[current_key] += 1
        if keep_case:
            out.write(line)
        if event == "spline_output":
            keep_case = False
            current_key = None
missing = [key for key, count in keep_counts.items() if seen_counts[key] != count]
if missing:
    raise SystemExit(f"missing spline keep cases: {missing}")
PY
rm -f "$TMP_FILE"

echo "Wrote $OUT_FILE"
