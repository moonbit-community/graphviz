#!/usr/bin/env bash
# Copyright (c) 2026 International Digital Economy Academy
# This program is made available under the terms of the Eclipse Public License 2.0.
# SPDX-License-Identifier: EPL-2.0

set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <external-graphviz-dot-bin>" >&2
  exit 2
fi

dot_bin="$1"
if [[ -x "${dot_bin}" ]]; then
  :
elif command -v "${dot_bin}" >/dev/null 2>&1; then
  dot_bin="$(command -v "${dot_bin}")"
else
  echo "Graphviz dot binary not found: ${dot_bin}" >&2
  exit 1
fi

version="$("${dot_bin}" -V 2>&1)"
if [[ "${version}" != *"graphviz version 14.1.1"* ]]; then
  echo "strict parity fixtures require external Graphviz 14.1.1; got: ${version}" >&2
  exit 1
fi

printf '%s\n' "${dot_bin}"
