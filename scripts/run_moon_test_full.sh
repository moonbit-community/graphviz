#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
default_jobs=$(
  getconf _NPROCESSORS_ONLN 2>/dev/null ||
    sysctl -n hw.ncpu 2>/dev/null ||
    echo 8
)
moon_jobs="${MOON_TEST_JOBS:-${default_jobs}}"
cc_wrapper="${repo_root}/scripts/moon_cc_wrapper.sh"

if [[ "${LOCAL_GUARD_SUPPRESS_CLANG_EXIT_WARNING:-1}" == "1" &&
  -z "${MOON_CC:-}" &&
  -x "${cc_wrapper}" ]]; then
  host_cc=$(command -v clang 2>/dev/null || command -v cc 2>/dev/null || true)
  host_ar=$(command -v ar 2>/dev/null || true)
  if [[ -n "${host_cc}" ]]; then
    export MOON_CC="${cc_wrapper}"
    export MOON_CC_REAL="${host_cc}"
    if [[ -z "${MOON_AR:-}" && -n "${host_ar}" ]]; then
      export MOON_AR="${host_ar}"
    fi
  fi
fi

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
