#!/usr/bin/env python3
"""Shared strict-parity snapshot input candidate resolution."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


INPUT_CANDIDATES = (
    "refs/graphviz/graphs/directed/{case}.gv",
    "refs/graphviz/graphs/undirected/{case}.gv",
    "tests/layout/dot/{case}.dot",
    "refs/graphviz/doc/dotguide/{case}.dot",
    "refs/graphviz/doc/infosrc/{case}.dot",
    "refs/graphviz/doc/infosrc/{case}.gv",
    "refs/graphviz/doc/neato/{case}.dot",
    "refs/graphviz/contrib/prune/{case}.gv",
    "refs/graphviz/contrib/dirgraph/{case}.dot",
    "refs/graphviz/contrib/java-dot/{case}.dot",
    "refs/graphviz/tests/{case}.dot",
    "refs/graphviz/tests/graphs/{case}.gv",
    "refs/graphviz/tests/share/{case}.gv",
    "refs/graphviz/tests/windows/{case}.gv",
    "refs/graphviz/tests/regression_tests/{case}.gv",
    "refs/graphviz/tests/regression_tests/shapes/reference/{case}.gv",
    "refs/graphviz/tests/linux.x86/{case}.gv",
    "refs/graphviz/tests/nshare/{case}.gv",
    "refs/graphviz/tests/linux.i386/{case}.gv",
    "refs/graphviz/tests/macosx/{case}.gv",
)


def resolve_input_path(repo_root: Path, case_name: str) -> Path:
    for rel in INPUT_CANDIDATES:
        path = repo_root / rel.format(case=case_name)
        if path.exists():
            return path
    raise FileNotFoundError(f"missing input for case: {case_name}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Resolve strict-parity snapshot input path for a case.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root path (default: inferred from script path).",
    )
    parser.add_argument(
        "--case",
        required=True,
        help="Snapshot case name to resolve.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    try:
        path = resolve_input_path(repo_root, args.case)
    except FileNotFoundError as exc:
        print(str(exc), file=sys.stderr)
        return 1
    print(path)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
