#!/usr/bin/env python3
"""Ensure DOT_CAPTURE_ORDERING_INPUTS does not alter rendered bytes."""

from __future__ import annotations

import argparse
import difflib
import os
import subprocess
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
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate DOT_CAPTURE_ORDERING_INPUTS output invariance.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root path (default: inferred from script path).",
    )
    parser.add_argument(
        "--dot-bin",
        type=Path,
        default=None,
        help="Path to dot CLI binary under test.",
    )
    parser.add_argument(
        "--formats",
        nargs="+",
        choices=("dot", "xdot", "svg"),
        default=["dot"],
        help="Formats to compare (default: dot).",
    )
    parser.add_argument(
        "--cases",
        nargs="+",
        default=None,
        help="Optional case-name allowlist.",
    )
    parser.add_argument(
        "--cases-file",
        type=Path,
        default=Path("tests/capture_env_invariant_cases.txt"),
        help="Optional newline-delimited case allowlist file.",
    )
    parser.add_argument(
        "--write-diff",
        action="store_true",
        help="Write mismatched outputs/diffs under target/capture-env-invariance.",
    )
    return parser.parse_args()


def resolve_input_path(repo_root: Path, case_name: str) -> Path:
    for rel in INPUT_CANDIDATES:
        path = repo_root / rel.format(case=case_name)
        if path.exists():
            return path
    raise FileNotFoundError(f"missing input for case: {case_name}")


def load_case_names(repo_root: Path, args: argparse.Namespace) -> list[str]:
    if args.cases:
        return list(dict.fromkeys(args.cases))
    path = args.cases_file
    if not path.is_absolute():
        path = repo_root / path
    if not path.exists():
        raise FileNotFoundError(f"cases file not found: {path}")
    names: list[str] = []
    seen: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line in seen:
            continue
        seen.add(line)
        names.append(line)
    if not names:
        raise ValueError(f"empty case list: {path}")
    return names


def ensure_dot_bin(repo_root: Path, dot_bin: Path | None) -> Path:
    if dot_bin is None:
        dot_bin = repo_root / "_build/native/debug/build/cmd/dot/dot.exe"
    elif not dot_bin.is_absolute():
        dot_bin = repo_root / dot_bin
    dot_bin = dot_bin.resolve()
    if not dot_bin.exists():
        raise FileNotFoundError(f"dot binary not found: {dot_bin}")
    return dot_bin


def run_case(
    dot_bin: Path,
    repo_root: Path,
    fmt: str,
    input_path: Path,
    capture: bool,
) -> bytes:
    env = os.environ.copy()
    if capture:
        env["DOT_CAPTURE_ORDERING_INPUTS"] = "1"
    else:
        env.pop("DOT_CAPTURE_ORDERING_INPUTS", None)
    proc = subprocess.run(
        [str(dot_bin), "-Kdot", f"-T{fmt}", str(input_path)],
        cwd=repo_root,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.decode("utf-8", errors="replace").strip()
        mode = "capture=1" if capture else "capture=0"
        raise RuntimeError(
            f"dot failed ({mode}) for {fmt} {input_path}: {stderr or '(no stderr)'}"
        )
    return proc.stdout


def maybe_write_diff(
    repo_root: Path,
    fmt: str,
    case_name: str,
    expected: bytes,
    actual: bytes,
) -> None:
    base = repo_root / "target/capture-env-invariance"
    expected_path = base / "expected" / fmt / f"{case_name}.{fmt}"
    actual_path = base / "actual" / fmt / f"{case_name}.{fmt}"
    diff_path = base / "diff" / fmt / f"{case_name}.diff"
    expected_path.parent.mkdir(parents=True, exist_ok=True)
    actual_path.parent.mkdir(parents=True, exist_ok=True)
    diff_path.parent.mkdir(parents=True, exist_ok=True)
    expected_path.write_bytes(expected)
    actual_path.write_bytes(actual)
    expected_text = expected.decode("utf-8", errors="replace").splitlines(keepends=True)
    actual_text = actual.decode("utf-8", errors="replace").splitlines(keepends=True)
    unified = difflib.unified_diff(
        expected_text,
        actual_text,
        fromfile=f"expected/{fmt}/{case_name}.{fmt}",
        tofile=f"actual/{fmt}/{case_name}.{fmt}",
    )
    diff_path.write_text("".join(unified), encoding="utf-8")


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    dot_bin = ensure_dot_bin(repo_root, args.dot_bin)
    cases = load_case_names(repo_root, args)

    has_failures = False
    for fmt in args.formats:
        mismatches: list[str] = []
        for case in cases:
            input_path = resolve_input_path(repo_root, case)
            base = run_case(dot_bin, repo_root, fmt, input_path, capture=False)
            capture = run_case(dot_bin, repo_root, fmt, input_path, capture=True)
            if base == capture:
                continue
            mismatches.append(case)
            if args.write_diff:
                maybe_write_diff(repo_root, fmt, case, base, capture)
        print(f"format={fmt} total={len(cases)} mismatches={len(mismatches)}")
        if mismatches:
            has_failures = True
            print("  " + " ".join(mismatches))
    return 1 if has_failures else 0


if __name__ == "__main__":
    sys.exit(main())
