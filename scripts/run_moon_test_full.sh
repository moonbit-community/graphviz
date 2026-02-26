#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

cd "${repo_root}"
DOT_RUN_FULL_PARITY_TESTS=1 \
  moon test --target native --release -j "${MOON_TEST_JOBS:-8}" "$@"
