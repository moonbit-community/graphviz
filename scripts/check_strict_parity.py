#!/usr/bin/env python3
"""Strict byte-for-byte parity checker for dot/xdot/svg fixtures."""

from __future__ import annotations

import argparse
import json
import subprocess
import sys
from dataclasses import dataclass
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


@dataclass(frozen=True)
class FormatConfig:
    manifest: str
    fixture_dir: str
    suffix: str
    out_ext: str


FORMAT_CONFIG = {
    "dot": FormatConfig(
        manifest="tests/layout/dot/cases.txt",
        fixture_dir="tests/layout/dot",
        suffix=".gv.dot",
        out_ext=".gv.dot",
    ),
    "xdot": FormatConfig(
        manifest="tests/render/xdot/cases.txt",
        fixture_dir="tests/render/xdot",
        suffix=".xdot",
        out_ext=".xdot",
    ),
    "svg": FormatConfig(
        manifest="tests/render/svg_snapshot/cases.txt",
        fixture_dir="tests/render/svg_snapshot",
        suffix=".svg",
        out_ext=".svg",
    ),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Strict byte-level parity checker for dot/xdot/svg fixtures.",
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
        "--build-if-missing",
        action="store_true",
        help="Run `moon build src/cmd/dot --target native` if dot binary is missing.",
    )
    parser.add_argument(
        "--formats",
        nargs="+",
        choices=sorted(FORMAT_CONFIG.keys()),
        default=["dot", "xdot", "svg"],
        help="Formats to compare (default: dot xdot svg).",
    )
    parser.add_argument(
        "--focus",
        nargs="+",
        default=None,
        help="Optional case-name allowlist (e.g. --focus ldbxtried typeshar).",
    )
    parser.add_argument(
        "--write-actual",
        action="store_true",
        help="Write actual outputs to target/render/<format>/ for mismatched cases.",
    )
    parser.add_argument(
        "--report-json",
        type=Path,
        default=None,
        help="Optional JSON report path for CI/debugging.",
    )
    return parser.parse_args()


def load_case_names(manifest_path: Path) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for raw in manifest_path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line in seen:
            raise ValueError(f"duplicate case in manifest {manifest_path}: {line}")
        seen.add(line)
        names.append(line)
    if not names:
        raise ValueError(f"empty case manifest: {manifest_path}")
    return names


def load_manifest_case_names(repo_root: Path, fmt: str) -> list[str]:
    config = FORMAT_CONFIG[fmt]
    manifest_path = repo_root / config.manifest
    return load_case_names(manifest_path)


def validate_manifest_alignment(repo_root: Path, formats: list[str]) -> None:
    if len(formats) <= 1:
        return
    baseline_fmt = formats[0]
    baseline = load_manifest_case_names(repo_root, baseline_fmt)
    for fmt in formats[1:]:
        current = load_manifest_case_names(repo_root, fmt)
        if current == baseline:
            continue
        base_set = set(baseline)
        current_set = set(current)
        missing = sorted(base_set - current_set)
        extra = sorted(current_set - base_set)
        details: list[str] = []
        if missing:
            details.append(f"missing in {fmt}: {' '.join(missing)}")
        if extra:
            details.append(f"extra in {fmt}: {' '.join(extra)}")
        if not details and len(current) == len(baseline):
            first_diff = next(
                idx
                for idx, (left, right) in enumerate(zip(baseline, current))
                if left != right
            )
            details.append(
                "different order at index "
                f"{first_diff}: {baseline[first_diff]} != {current[first_diff]}",
            )
        raise ValueError(
            "manifest case lists diverge between formats "
            f"{baseline_fmt} and {fmt}: " + "; ".join(details),
        )


def resolve_input_path(repo_root: Path, case_name: str) -> Path:
    for rel in INPUT_CANDIDATES:
        path = repo_root / rel.format(case=case_name)
        if path.exists():
            return path
    raise FileNotFoundError(f"missing input for case: {case_name}")


def fixture_path(repo_root: Path, fmt: str, case_name: str) -> Path:
    config = FORMAT_CONFIG[fmt]
    if fmt == "dot" and case_name == "grammar":
        return repo_root / config.fixture_dir / "grammar.dot"
    return repo_root / config.fixture_dir / f"{case_name}{config.suffix}"


def validate_fixture_coverage(repo_root: Path, fmt: str, manifest_cases: list[str]) -> None:
    config = FORMAT_CONFIG[fmt]
    fixture_dir = repo_root / config.fixture_dir
    manifest_set = set(manifest_cases)
    extras: list[str] = []
    for entry in fixture_dir.iterdir():
        if not entry.is_file():
            continue
        if fmt == "dot":
            if entry.name == "grammar.dot":
                case_name = "grammar"
            elif entry.name.endswith(".gv.dot"):
                case_name = entry.name[: -len(".gv.dot")]
            else:
                continue
        else:
            if not entry.name.endswith(config.suffix):
                continue
            case_name = entry.name[: -len(config.suffix)]
        if case_name not in manifest_set:
            extras.append(str(entry.relative_to(repo_root)))
    if extras:
        extras.sort()
        raise ValueError(
            f"uncovered fixtures for {fmt}: " + ", ".join(extras),
        )
    for case_name in manifest_cases:
        expected = fixture_path(repo_root, fmt, case_name)
        if not expected.exists():
            raise FileNotFoundError(f"missing fixture for {fmt}: {expected}")
        resolve_input_path(repo_root, case_name)


def run_case(dot_bin: Path, fmt: str, input_path: Path, repo_root: Path) -> bytes:
    proc = subprocess.run(
        [str(dot_bin), "-Kdot", f"-T{fmt}", str(input_path)],
        cwd=repo_root,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        check=False,
    )
    if proc.returncode != 0:
        stderr = proc.stderr.decode("utf-8", errors="replace").strip()
        raise RuntimeError(
            f"dot failed for {fmt} {input_path}: {stderr or '(no stderr)'}",
        )
    return proc.stdout


def ensure_dot_bin(args: argparse.Namespace) -> Path:
    repo_root = args.repo_root.resolve()
    default_bin = repo_root / "_build/native/debug/build/cmd/dot/dot.exe"
    dot_bin = args.dot_bin.resolve() if args.dot_bin else default_bin
    if dot_bin.exists():
        return dot_bin
    if not args.build_if_missing:
        raise FileNotFoundError(
            f"dot binary not found: {dot_bin} (pass --build-if-missing to build it)",
        )
    subprocess.run(
        ["moon", "build", "src/cmd/dot", "--target", "native"],
        cwd=repo_root,
        check=True,
    )
    if not dot_bin.exists():
        raise FileNotFoundError(f"dot binary still missing after build: {dot_bin}")
    return dot_bin


def maybe_write_actual(
    repo_root: Path,
    fmt: str,
    case_name: str,
    data: bytes,
) -> None:
    config = FORMAT_CONFIG[fmt]
    out_dir = repo_root / "target" / "render" / fmt
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{case_name}{config.out_ext}"
    out_path.write_bytes(data)


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    dot_bin = ensure_dot_bin(args)
    focus_set = set(args.focus or [])
    if not focus_set:
        validate_manifest_alignment(repo_root, args.formats)

    had_mismatch = False
    report_entries: list[dict[str, object]] = []
    for fmt in args.formats:
        config = FORMAT_CONFIG[fmt]
        manifest_path = repo_root / config.manifest
        case_names = load_case_names(manifest_path)
        if focus_set:
            unknown = sorted(focus_set.difference(case_names))
            if unknown:
                raise ValueError(
                    f"unknown focus cases for {fmt}: " + ", ".join(unknown),
                )
            case_names = [name for name in case_names if name in focus_set]
            if not case_names:
                raise ValueError(f"no focused cases remain for {fmt}")
        else:
            validate_fixture_coverage(repo_root, fmt, case_names)

        mismatches: list[str] = []
        for case_name in case_names:
            input_path = resolve_input_path(repo_root, case_name)
            expected_path = fixture_path(repo_root, fmt, case_name)
            expected = expected_path.read_bytes()
            actual = run_case(dot_bin, fmt, input_path, repo_root)
            if actual != expected:
                mismatches.append(case_name)
                if args.write_actual:
                    maybe_write_actual(repo_root, fmt, case_name, actual)

        print(f"format={fmt} total={len(case_names)} mismatches={len(mismatches)}")
        if mismatches:
            had_mismatch = True
            print("  " + " ".join(mismatches))
        report_entries.append(
            {
                "format": fmt,
                "total": len(case_names),
                "mismatch_count": len(mismatches),
                "mismatches": mismatches,
            }
        )

    if args.report_json is not None:
        report_path = args.report_json
        if not report_path.is_absolute():
            report_path = repo_root / report_path
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_payload = {
            "repo_root": str(repo_root),
            "dot_bin": str(dot_bin),
            "formats": args.formats,
            "focus_cases": sorted(focus_set),
            "had_mismatch": had_mismatch,
            "results": report_entries,
        }
        report_path.write_text(
            json.dumps(report_payload, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )

    return 1 if had_mismatch else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except KeyboardInterrupt:
        raise SystemExit(130)
