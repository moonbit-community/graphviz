#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
GRAPHVIZ_DIR="$ROOT/refs/graphviz"
PATCH_FILE="$ROOT/tools/graphviz-capture/patches/textspan.patch"
BUILD_DIR="$GRAPHVIZ_DIR/build"
OUT_DIR="$ROOT/tests/fixtures/graphviz"
OUT_FILE="$OUT_DIR/textspan.jsonl"
TMP_FILE="$OUT_DIR/textspan.jsonl.tmp"

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
  HAS_MARKER=$(rg -q "MBT_CAPTURE_TEXTSPAN" "$GRAPHVIZ_DIR/lib/common/textspan.c" && echo yes || echo no)
else
  HAS_MARKER=$(grep -q "MBT_CAPTURE_TEXTSPAN" "$GRAPHVIZ_DIR/lib/common/textspan.c" && echo yes || echo no)
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

# Use only source .dot/.gv inputs; .gv.dot snapshots include bare attrs that Graphviz won't parse.
inputs=(
  "$ROOT"/tests/layout/dot/*.dot
  "$ROOT"/refs/graphviz/doc/dotguide/*.dot
  "$ROOT"/refs/graphviz/doc/infosrc/*.dot
  "$ROOT"/refs/graphviz/doc/infosrc/*.gv
  "$ROOT"/refs/graphviz/doc/neato/*.dot
  "$ROOT"/refs/graphviz/doc/neato/*.gv
  "$ROOT"/refs/graphviz/contrib/dirgraph/*.dot
  "$ROOT"/refs/graphviz/contrib/java-dot/*.dot
  "$ROOT"/refs/graphviz/graphs/directed/*.gv
  "$ROOT"/refs/graphviz/graphs/directed/*.dot
  "$ROOT"/refs/graphviz/graphs/undirected/*.gv
  "$ROOT"/refs/graphviz/graphs/undirected/*.dot
)
for input in "${inputs[@]}"; do
  if [[ "$input" == *.gv.dot ]]; then
    continue
  fi
  MBT_CAPTURE_TEXTSPAN="$TMP_FILE" "$DOT_BIN" -Txdot "$input" >/dev/null
done

mv "$TMP_FILE" "$OUT_FILE"

echo "Wrote $OUT_FILE"
