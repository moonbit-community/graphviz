#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
default_jobs=$(
  getconf _NPROCESSORS_ONLN 2>/dev/null ||
    sysctl -n hw.ncpu 2>/dev/null ||
    echo 8
)
moon_jobs="${MOON_TEST_JOBS:-${default_jobs}}"

cd "${repo_root}"
DOT_RUN_FULL_PARITY_TESTS=1 \
  moon test --target native --release --deny-warn -j "${moon_jobs}" "$@"

scripts/check_snapshot_input_candidates.py
scripts/check_strict_parity_case_lists.py

moon build src/cmd/dot --target native --release -j "${moon_jobs}"
dot_bin="_build/native/release/build/cmd/dot/dot.exe"

scripts/check_capture_env_invariance.py \
  --dot-bin "${dot_bin}" \
  --formats dot xdot svg \
  --cases-file tests/capture_env_invariant_cases.txt
