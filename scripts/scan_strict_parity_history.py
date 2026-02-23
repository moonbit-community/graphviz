#!/usr/bin/env python3
"""Scan a commit range with strict parity checks."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run strict parity checks across a commit range.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root path (default: inferred from script path).",
    )
    parser.add_argument(
        "--good",
        required=True,
        help="Known-good commit hash (inclusive).",
    )
    parser.add_argument(
        "--bad",
        required=True,
        help="Range end commit hash (inclusive).",
    )
    parser.add_argument(
        "--formats",
        nargs="+",
        default=["dot", "xdot", "svg"],
        choices=["dot", "xdot", "svg"],
        help="Formats to compare (default: dot xdot svg).",
    )
    parser.add_argument(
        "--focus",
        nargs="+",
        default=None,
        help="Optional case-name allowlist forwarded to strict parity checker.",
    )
    parser.add_argument(
        "--keep-temp",
        action="store_true",
        help="Keep temporary worktrees for debugging.",
    )
    return parser.parse_args()


def run(
    args: list[str],
    cwd: Path,
    *,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=check,
    )


def commit_list(repo_root: Path, good: str, bad: str) -> list[str]:
    rev_good = run(["git", "rev-parse", good], repo_root).stdout.strip()
    rev_bad = run(["git", "rev-parse", bad], repo_root).stdout.strip()
    chain = run(
        ["git", "rev-list", "--reverse", "--ancestry-path", f"{rev_good}..{rev_bad}"],
        repo_root,
    ).stdout.splitlines()
    return [rev_good] + chain


def short_hash(repo_root: Path, commit: str) -> str:
    return run(["git", "rev-parse", "--short", commit], repo_root).stdout.strip()


def parse_mismatch_counts(output: str) -> dict[str, int]:
    result: dict[str, int] = {}
    for line in output.splitlines():
        line = line.strip()
        if not line.startswith("format="):
            continue
        parts = line.split()
        if len(parts) != 3:
            continue
        fmt = parts[0].split("=", 1)[1]
        mismatch_count = int(parts[2].split("=", 1)[1])
        result[fmt] = mismatch_count
    return result


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    checker = repo_root / "scripts" / "check_strict_parity.py"
    if not checker.exists():
        raise FileNotFoundError(f"strict parity checker not found: {checker}")

    commits = commit_list(repo_root, args.good, args.bad)
    if not commits:
        raise ValueError("no commits to scan")

    temp_root = Path(tempfile.mkdtemp(prefix="strict_parity_scan."))
    print(f"scan temp dir: {temp_root}")
    any_bad = False
    try:
        for commit in commits:
            short = short_hash(repo_root, commit)
            worktree = temp_root / short
            run(
                ["git", "worktree", "add", "--detach", str(worktree), commit],
                repo_root,
            )
            try:
                run(
                    ["git", "submodule", "update", "--init", "refs/graphviz"],
                    worktree,
                )
                run(
                    ["moon", "build", "src/cmd/dot", "--target", "native"],
                    worktree,
                )
                cmd = [
                    sys.executable,
                    str(checker),
                    "--repo-root",
                    str(worktree),
                    "--formats",
                    *args.formats,
                ]
                if args.focus:
                    cmd.extend(["--focus", *args.focus])
                parity = run(cmd, worktree, check=False)
                counts = parse_mismatch_counts(parity.stdout)
                summary = " ".join(
                    f"{fmt}={counts.get(fmt, -1)}" for fmt in args.formats
                )
                status = "PASS" if parity.returncode == 0 else "FAIL"
                print(f"{short} {status} {summary}")
                if parity.returncode != 0:
                    any_bad = True
                    for line in parity.stdout.splitlines():
                        if line.startswith("  "):
                            print(f"  {line.strip()}")
            finally:
                run(
                    ["git", "worktree", "remove", "--force", str(worktree)],
                    repo_root,
                )
    finally:
        if args.keep_temp:
            print(f"kept temp dir: {temp_root}")
        else:
            shutil.rmtree(temp_root, ignore_errors=True)

    return 1 if any_bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
