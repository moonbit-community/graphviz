#!/usr/bin/env python3
"""Locate first strict parity regression commit on a linear ancestry path."""

from __future__ import annotations

import argparse
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Find first commit that fails strict parity checks.",
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
        help="Known-good commit hash (must pass strict parity).",
    )
    parser.add_argument(
        "--bad",
        required=True,
        help="Known-bad commit hash (must fail strict parity).",
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


def commit_chain(repo_root: Path, good: str, bad: str) -> list[str]:
    rev_good = run(["git", "rev-parse", good], repo_root).stdout.strip()
    rev_bad = run(["git", "rev-parse", bad], repo_root).stdout.strip()
    chain = run(
        ["git", "rev-list", "--reverse", "--ancestry-path", f"{rev_good}..{rev_bad}"],
        repo_root,
    ).stdout.splitlines()
    return [rev_good] + chain


def short_hash(repo_root: Path, commit: str) -> str:
    return run(["git", "rev-parse", "--short", commit], repo_root).stdout.strip()


def parse_counts(stdout: str) -> dict[str, int]:
    counts: dict[str, int] = {}
    for line in stdout.splitlines():
        line = line.strip()
        if not line.startswith("format="):
            continue
        parts = line.split()
        if len(parts) != 3:
            continue
        fmt = parts[0].split("=", 1)[1]
        mismatches = int(parts[2].split("=", 1)[1])
        counts[fmt] = mismatches
    return counts


class CommitEvaluator:
    def __init__(
        self,
        repo_root: Path,
        checker: Path,
        formats: list[str],
        focus: list[str] | None,
        temp_root: Path,
    ) -> None:
        self.repo_root = repo_root
        self.checker = checker
        self.formats = formats
        self.focus = focus
        self.temp_root = temp_root
        self.cache: dict[str, tuple[bool, dict[str, int], str]] = {}

    def evaluate(self, commit: str) -> tuple[bool, dict[str, int], str]:
        cached = self.cache.get(commit)
        if cached is not None:
            return cached

        short = short_hash(self.repo_root, commit)
        worktree = self.temp_root / f"bisect-{short}"
        run(
            ["git", "worktree", "add", "--detach", str(worktree), commit],
            self.repo_root,
        )
        try:
            run(["git", "submodule", "update", "--init", "refs/graphviz"], worktree)
            run(["moon", "build", "src/cmd/dot", "--target", "native"], worktree)
            cmd = [
                sys.executable,
                str(self.checker),
                "--repo-root",
                str(worktree),
                "--formats",
                *self.formats,
            ]
            if self.focus:
                cmd.extend(["--focus", *self.focus])
            parity = run(cmd, worktree, check=False)
            passed = parity.returncode == 0
            counts = parse_counts(parity.stdout)
            result = (passed, counts, parity.stdout.strip())
            self.cache[commit] = result
            return result
        finally:
            run(
                ["git", "worktree", "remove", "--force", str(worktree)],
                self.repo_root,
            )


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    checker = repo_root / "scripts" / "check_strict_parity.py"
    if not checker.exists():
        raise FileNotFoundError(f"strict parity checker not found: {checker}")

    chain = commit_chain(repo_root, args.good, args.bad)
    if len(chain) < 2:
        raise ValueError("good and bad resolve to the same commit")

    temp_root = Path(tempfile.mkdtemp(prefix="strict_parity_bisect."))
    print(f"bisect temp dir: {temp_root}")
    try:
        evaluator = CommitEvaluator(
            repo_root,
            checker,
            args.formats,
            args.focus,
            temp_root,
        )

        good_ok, good_counts, _ = evaluator.evaluate(chain[0])
        bad_ok, bad_counts, _ = evaluator.evaluate(chain[-1])
        print(
            f"{short_hash(repo_root, chain[0])} "
            f"{'PASS' if good_ok else 'FAIL'} "
            + " ".join(f"{fmt}={good_counts.get(fmt, -1)}" for fmt in args.formats)
        )
        print(
            f"{short_hash(repo_root, chain[-1])} "
            f"{'PASS' if bad_ok else 'FAIL'} "
            + " ".join(f"{fmt}={bad_counts.get(fmt, -1)}" for fmt in args.formats)
        )
        if not good_ok:
            raise RuntimeError("known-good commit does not pass strict parity")
        if bad_ok:
            raise RuntimeError("known-bad commit does not fail strict parity")

        low = 0
        high = len(chain) - 1
        probes = 0
        while high - low > 1:
            mid = (low + high) // 2
            commit = chain[mid]
            ok, counts, _ = evaluator.evaluate(commit)
            probes += 1
            status = "PASS" if ok else "FAIL"
            print(
                f"probe {probes}: {short_hash(repo_root, commit)} {status} "
                + " ".join(f"{fmt}={counts.get(fmt, -1)}" for fmt in args.formats)
            )
            if ok:
                low = mid
            else:
                high = mid

        first_bad = chain[high]
        first_bad_short = short_hash(repo_root, first_bad)
        prev_good = chain[high - 1]
        prev_good_short = short_hash(repo_root, prev_good)
        print(f"first bad commit: {first_bad_short} ({first_bad})")
        print(f"last good commit:  {prev_good_short} ({prev_good})")
        return 0
    finally:
        if args.keep_temp:
            print(f"kept temp dir: {temp_root}")
        else:
            shutil.rmtree(temp_root, ignore_errors=True)


if __name__ == "__main__":
    raise SystemExit(main())
