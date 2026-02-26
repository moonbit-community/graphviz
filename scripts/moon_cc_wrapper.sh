#!/usr/bin/env bash
set -euo pipefail

cc_bin="${MOON_CC_REAL:-}"
if [[ -z "${cc_bin}" ]]; then
  cc_bin=$(command -v clang 2>/dev/null || true)
fi
if [[ -z "${cc_bin}" ]]; then
  cc_bin=$(command -v cc 2>/dev/null || true)
fi
if [[ -z "${cc_bin}" ]]; then
  echo "moon_cc_wrapper: no host C compiler found" >&2
  exit 127
fi

exec "${cc_bin}" -Wno-incompatible-library-redeclaration "$@"
