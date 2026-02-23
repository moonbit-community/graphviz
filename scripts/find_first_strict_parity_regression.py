#!/usr/bin/env python3
"""Locate first strict parity regression commit on a linear ancestry path."""

from __future__ import annotations

import argparse
import json
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
    parser.add_argument(
        "--report-json",
        type=Path,
        default=None,
        help="Optional JSON report path for CI/debugging.",
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


def counts_summary(formats: list[str], counts: dict[str, int]) -> str:
    return " ".join(f"{fmt}={counts.get(fmt, -1)}" for fmt in formats)


def parse_checker_report(
    report_path: Path,
    formats: list[str],
    stdout: str,
) -> tuple[dict[str, int], dict[str, list[str]]]:
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
                    return counts, mismatches_by_format
        except Exception:
            pass

    counts = parse_counts(stdout)
    mismatches_by_format = {fmt: [] for fmt in formats}
    return counts, mismatches_by_format


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
        self.cache: dict[
            str,
            tuple[bool, dict[str, int], dict[str, list[str]], str],
        ] = {}

    def evaluate(
        self,
        commit: str,
    ) -> tuple[bool, dict[str, int], dict[str, list[str]], str]:
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
            report_file = worktree / "target" / "strict-parity" / "check-report.json"
            cmd.extend(["--report-json", str(report_file)])
            parity = run(cmd, worktree, check=False)
            passed = parity.returncode == 0
            counts, mismatches_by_format = parse_checker_report(
                report_file,
                self.formats,
                parity.stdout,
            )
            result = (passed, counts, mismatches_by_format, parity.stdout.strip())
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
    report: dict[str, object] = {
        "repo_root": str(repo_root),
        "good": args.good,
        "bad": args.bad,
        "formats": args.formats,
        "focus_cases": sorted(set(args.focus or [])),
        "good_result": None,
        "bad_result": None,
        "probes": [],
        "first_bad": None,
        "last_good": None,
    }
    exit_code = 0
    try:
        evaluator = CommitEvaluator(
            repo_root,
            checker,
            args.formats,
            args.focus,
            temp_root,
        )

        good_ok, good_counts, good_mismatches, _ = evaluator.evaluate(chain[0])
        bad_ok, bad_counts, bad_mismatches, _ = evaluator.evaluate(chain[-1])
        report["good_result"] = {
            "commit": chain[0],
            "short": short_hash(repo_root, chain[0]),
            "passed": good_ok,
            "counts": good_counts,
            "mismatches_by_format": good_mismatches,
        }
        report["bad_result"] = {
            "commit": chain[-1],
            "short": short_hash(repo_root, chain[-1]),
            "passed": bad_ok,
            "counts": bad_counts,
            "mismatches_by_format": bad_mismatches,
        }
        print(
            f"{short_hash(repo_root, chain[0])} "
            f"{'PASS' if good_ok else 'FAIL'} {counts_summary(args.formats, good_counts)}"
        )
        print(
            f"{short_hash(repo_root, chain[-1])} "
            f"{'PASS' if bad_ok else 'FAIL'} {counts_summary(args.formats, bad_counts)}"
        )
        if not good_ok:
            raise RuntimeError(
                "known-good commit does not pass strict parity",
            )
        if bad_ok:
            raise RuntimeError(
                "known-bad commit does not fail strict parity",
            )

        low = 0
        high = len(chain) - 1
        probes = 0
        while high - low > 1:
            mid = (low + high) // 2
            commit = chain[mid]
            ok, counts, mismatches_by_format, _ = evaluator.evaluate(commit)
            probes += 1
            status = "PASS" if ok else "FAIL"
            print(
                f"probe {probes}: {short_hash(repo_root, commit)} {status} "
                + counts_summary(args.formats, counts)
            )
            probe_entry: dict[str, object] = {
                "index": probes,
                "commit": commit,
                "short": short_hash(repo_root, commit),
                "passed": ok,
                "counts": counts,
                "mismatches_by_format": mismatches_by_format,
            }
            report_probes = report.get("probes")
            if isinstance(report_probes, list):
                report_probes.append(probe_entry)
            if ok:
                low = mid
            else:
                high = mid

        first_bad = chain[high]
        first_bad_short = short_hash(repo_root, first_bad)
        prev_good = chain[high - 1]
        prev_good_short = short_hash(repo_root, prev_good)
        report["first_bad"] = {
            "commit": first_bad,
            "short": first_bad_short,
        }
        report["last_good"] = {
            "commit": prev_good,
            "short": prev_good_short,
        }
        print(f"first bad commit: {first_bad_short} ({first_bad})")
        print(f"last good commit:  {prev_good_short} ({prev_good})")
    except Exception as exc:
        exit_code = 1
        report["error"] = str(exc)
        print(f"error: {exc}", file=sys.stderr)
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
            report["exit_code"] = exit_code
            report_path.write_text(
                json.dumps(report, indent=2, sort_keys=True) + "\n",
                encoding="utf-8",
            )

    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
