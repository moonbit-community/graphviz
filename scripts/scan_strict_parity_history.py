#!/usr/bin/env python3
"""Scan a commit range with strict parity checks."""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

from case_list_utils import dedupe_case_names
from case_list_utils import load_case_names
from case_list_utils import resolve_repo_path


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
        "--focus-file",
        type=Path,
        default=None,
        help="Optional newline-delimited case allowlist file (supports comments).",
    )
    parser.add_argument(
        "--keep-temp",
        action="store_true",
        help="Keep temporary worktrees for debugging.",
    )
    parser.add_argument(
        "--report-json",
        type=Path,
        default=None,
        help="Optional JSON report path for CI/debugging.",
    )
    return parser.parse_args()


def resolve_focus_cases(
    repo_root: Path,
    focus: list[str] | None,
    focus_file: Path | None,
) -> list[str] | None:
    merged: list[str] = []
    if focus:
        merged.extend(focus)
    if focus_file is not None:
        path = resolve_repo_path(repo_root, focus_file)
        merged.extend(load_case_names(path, dedupe=True))
    if not merged:
        return None
    return dedupe_case_names(merged)


def run(
    args: list[str],
    cwd: Path,
    *,
    check: bool = True,
    env: dict[str, str] | None = None,
) -> subprocess.CompletedProcess[str]:
    proc_env = None
    if env:
        proc_env = os.environ.copy()
        proc_env.update(env)
    return subprocess.run(
        args,
        cwd=cwd,
        text=True,
        capture_output=True,
        check=check,
        env=proc_env,
    )


def submodule_update_args(repo_root: Path) -> list[str]:
    repo_submodule = repo_root / "refs" / "graphviz"
    if (repo_submodule / ".git").exists() or (repo_submodule / "objects").is_dir():
        return [
            "git",
            "submodule",
            "update",
            "--init",
            "--reference",
            str(repo_submodule),
            "refs/graphviz",
        ]
    return ["git", "submodule", "update", "--init", "refs/graphviz"]


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


def mismatch_lines(output: str) -> list[str]:
    lines: list[str] = []
    for line in output.splitlines():
        if line.startswith("  "):
            lines.append(line.strip())
    return lines


def parse_checker_report(
    report_path: Path,
    formats: list[str],
    stdout: str,
) -> tuple[dict[str, int], dict[str, list[str]], list[str]]:
    if report_path.exists():
        try:
            payload = json.loads(report_path.read_text(encoding="utf-8"))
            results = payload.get("results", [])
            if isinstance(results, list):
                counts: dict[str, int] = {}
                mismatches_by_format: dict[str, list[str]] = {}
                for entry in results:
                    if not isinstance(entry, dict):
                        continue
                    fmt = entry.get("format")
                    if not isinstance(fmt, str):
                        continue
                    mismatch_count = entry.get("mismatch_count", 0)
                    mismatches = entry.get("mismatches", [])
                    if not isinstance(mismatch_count, int):
                        mismatch_count = 0
                    if not isinstance(mismatches, list):
                        mismatches = []
                    counts[fmt] = mismatch_count
                    mismatches_by_format[fmt] = [
                        str(name) for name in mismatches if isinstance(name, str)
                    ]
                if counts:
                    for fmt in formats:
                        counts.setdefault(fmt, -1)
                        mismatches_by_format.setdefault(fmt, [])
                    detail_lines: list[str] = []
                    for fmt in formats:
                        names = mismatches_by_format.get(fmt, [])
                        if names:
                            detail_lines.append(f"{fmt}: {' '.join(names)}")
                    return counts, mismatches_by_format, detail_lines
        except Exception:
            pass

    counts = parse_mismatch_counts(stdout)
    details = mismatch_lines(stdout)
    mismatches_by_format = {fmt: [] for fmt in formats}
    return counts, mismatches_by_format, details


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    checker = repo_root / "scripts" / "check_strict_parity.py"
    if not checker.exists():
        raise FileNotFoundError(f"strict parity checker not found: {checker}")
    focus_cases = resolve_focus_cases(repo_root, args.focus, args.focus_file)

    commits = commit_list(repo_root, args.good, args.bad)
    if not commits:
        raise ValueError("no commits to scan")

    temp_root = Path(tempfile.mkdtemp(prefix="strict_parity_scan."))
    print(f"scan temp dir: {temp_root}")
    any_bad = False
    entries: list[dict[str, object]] = []
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
                    submodule_update_args(repo_root),
                    worktree,
                    env={"GIT_TERMINAL_PROMPT": "0"},
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
                if focus_cases:
                    cmd.extend(["--focus", *focus_cases])
                report_file = worktree / "target" / "strict-parity" / "check-report.json"
                cmd.extend(["--report-json", str(report_file)])
                parity = run(cmd, worktree, check=False)
                counts, mismatches_by_format, mismatch_details = parse_checker_report(
                    report_file,
                    args.formats,
                    parity.stdout,
                )
                summary = " ".join(
                    f"{fmt}={counts.get(fmt, -1)}" for fmt in args.formats
                )
                status = "PASS" if parity.returncode == 0 else "FAIL"
                print(f"{short} {status} {summary}")
                entries.append(
                    {
                        "commit": commit,
                        "short": short,
                        "status": status,
                        "passed": parity.returncode == 0,
                        "counts": counts,
                        "mismatches_by_format": mismatches_by_format,
                        "mismatch_details": mismatch_details,
                    }
                )
                if parity.returncode != 0:
                    any_bad = True
                    for line in mismatch_details:
                        print(f"  {line}")
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

    if args.report_json is not None:
        report_path = args.report_json
        if not report_path.is_absolute():
            report_path = repo_root / report_path
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report = {
            "repo_root": str(repo_root),
            "good": args.good,
            "bad": args.bad,
            "formats": args.formats,
            "focus_cases": sorted(focus_cases or []),
            "any_bad": any_bad,
            "entries": entries,
        }
        report_path.write_text(
            json.dumps(report, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    return 1 if any_bad else 0


if __name__ == "__main__":
    raise SystemExit(main())
