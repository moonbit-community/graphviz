#!/usr/bin/env bash
# Copyright (c) 2026 International Digital Economy Academy
# This program is made available under the terms of the Eclipse Public License 2.0.
# SPDX-License-Identifier: EPL-2.0


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
