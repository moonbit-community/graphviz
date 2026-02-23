#!/usr/bin/env python3
"""Validate strict parity focus list invariants."""

from __future__ import annotations

import argparse
from pathlib import Path


DEFAULT_REQUIRED_SENTINEL = ["ldbxtried", "typeshar", "trapeziumlr", "unix2"]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Validate strict parity sentinel/history case list invariants.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root path (default: inferred from script path).",
    )
    parser.add_argument(
        "--sentinel-file",
        type=Path,
        default=Path("tests/strict_parity_sentinel_cases.txt"),
        help="Sentinel case list file path.",
    )
    parser.add_argument(
        "--history-file",
        type=Path,
        default=Path("tests/strict_parity_history_focus_cases.txt"),
        help="History-focus case list file path.",
    )
    parser.add_argument(
        "--required-sentinel",
        nargs="+",
        default=DEFAULT_REQUIRED_SENTINEL,
        help="Required case names that must appear in sentinel list.",
    )
    parser.add_argument(
        "--known-regression-file",
        type=Path,
        default=Path("tests/strict_parity_known_regression_cases_f9bfd00.txt"),
        help="Known full-corpus regression case list that history focus must cover.",
    )
    return parser.parse_args()


def resolve_path(repo_root: Path, path: Path) -> Path:
    return path if path.is_absolute() else repo_root / path


def load_case_names(path: Path) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line in seen:
            raise ValueError(f"duplicate case in {path}: {line}")
        seen.add(line)
        names.append(line)
    if not names:
        raise ValueError(f"empty case list: {path}")
    return names


def load_manifest_case_names(repo_root: Path) -> tuple[list[str], list[str], list[str]]:
    dot_cases = load_case_names(repo_root / "tests/layout/dot/cases.txt")
    xdot_cases = load_case_names(repo_root / "tests/render/xdot/cases.txt")
    svg_cases = load_case_names(repo_root / "tests/render/svg_snapshot/cases.txt")
    return dot_cases, xdot_cases, svg_cases


def validate_manifest_alignment(
    dot_cases: list[str],
    xdot_cases: list[str],
    svg_cases: list[str],
) -> set[str]:
    if dot_cases != xdot_cases or dot_cases != svg_cases:
        raise ValueError("strict parity manifests diverge across dot/xdot/svg cases")
    return set(dot_cases)


def validate_subset(
    *,
    subset_name: str,
    subset_values: set[str],
    superset_name: str,
    superset_values: set[str],
) -> None:
    missing = sorted(subset_values - superset_values)
    if missing:
        raise ValueError(
            f"{subset_name} has cases not present in {superset_name}: " + ", ".join(missing),
        )


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    sentinel_path = resolve_path(repo_root, args.sentinel_file)
    history_path = resolve_path(repo_root, args.history_file)
    known_regression_path = resolve_path(repo_root, args.known_regression_file)

    dot_cases, xdot_cases, svg_cases = load_manifest_case_names(repo_root)
    manifest_set = validate_manifest_alignment(dot_cases, xdot_cases, svg_cases)

    sentinel_cases = load_case_names(sentinel_path)
    history_cases = load_case_names(history_path)
    known_regression_cases = load_case_names(known_regression_path)
    sentinel_set = set(sentinel_cases)
    history_set = set(history_cases)
    known_regression_set = set(known_regression_cases)

    required_sentinel = set(args.required_sentinel or [])
    validate_subset(
        subset_name="required sentinel",
        subset_values=required_sentinel,
        superset_name="sentinel list",
        superset_values=sentinel_set,
    )
    validate_subset(
        subset_name="sentinel list",
        subset_values=sentinel_set,
        superset_name="history list",
        superset_values=history_set,
    )
    validate_subset(
        subset_name="sentinel list",
        subset_values=sentinel_set,
        superset_name="strict parity manifests",
        superset_values=manifest_set,
    )
    validate_subset(
        subset_name="history list",
        subset_values=history_set,
        superset_name="strict parity manifests",
        superset_values=manifest_set,
    )
    validate_subset(
        subset_name="known regression list",
        subset_values=known_regression_set,
        superset_name="history list",
        superset_values=history_set,
    )
    validate_subset(
        subset_name="known regression list",
        subset_values=known_regression_set,
        superset_name="strict parity manifests",
        superset_values=manifest_set,
    )

    print(
        "strict parity case lists valid: "
        "sentinel="
        f"{len(sentinel_cases)} history={len(history_cases)} "
        f"known_regression={len(known_regression_cases)} manifests={len(manifest_set)}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
