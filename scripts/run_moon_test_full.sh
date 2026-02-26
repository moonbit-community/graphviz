#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

cd "${repo_root}"
DOT_RUN_FULL_PARITY_TESTS=1 \
  moon test --target native --release -j "${MOON_TEST_JOBS:-8}" "$@"

scripts/check_snapshot_input_candidates.py
scripts/check_strict_parity_case_lists.py

moon build src/cmd/dot --target native --release
dot_bin="_build/native/release/build/cmd/dot/dot.exe"

scripts/check_capture_env_invariance.py \
  --dot-bin "${dot_bin}" \
  --formats dot xdot svg \
  --cases-file tests/capture_env_invariant_cases.txt
