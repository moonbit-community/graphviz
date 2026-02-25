#!/usr/bin/env python3
"""Validate strict parity focus list invariants."""

from __future__ import annotations

import argparse
from pathlib import Path

from snapshot_inputs import INPUT_CANDIDATES as STRICT_PARITY_INPUT_CANDIDATES
from snapshot_inputs import resolve_input_path as resolve_snapshot_input_path

DEFAULT_REQUIRED_SENTINEL = ["ldbxtried", "typeshar", "trapeziumlr", "unix2"]
INPUT_CANDIDATE_PATTERNS = [
    "refs/graphviz/graphs/directed/*.gv",
    "refs/graphviz/graphs/undirected/*.gv",
    "refs/graphviz/doc/dotguide/*.dot",
    "refs/graphviz/doc/infosrc/*.dot",
    "refs/graphviz/doc/infosrc/*.gv",
    "refs/graphviz/doc/neato/*.dot",
    "refs/graphviz/contrib/prune/*.gv",
    "refs/graphviz/contrib/dirgraph/*.dot",
    "refs/graphviz/contrib/java-dot/*.dot",
]


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
    parser.add_argument(
        "--allowed-uncovered-file",
        type=Path,
        default=Path("tests/strict_parity_uncovered_input_cases.txt"),
        help="Case list allowed to exist in input corpus but not strict manifests.",
    )
    return parser.parse_args()


def resolve_path(repo_root: Path, path: Path) -> Path:
    return path if path.is_absolute() else repo_root / path


def load_case_names(path: Path, *, allow_empty: bool = False) -> list[str]:
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
    if not names and not allow_empty:
        raise ValueError(f"empty case list: {path}")
    return names


def load_manifest_case_names(repo_root: Path) -> tuple[list[str], list[str], list[str]]:
    dot_cases = load_case_names(repo_root / "tests/layout/dot/cases.txt")
    xdot_cases = load_case_names(repo_root / "tests/render/xdot/cases.txt")
    svg_cases = load_case_names(repo_root / "tests/render/svg_snapshot/cases.txt")
    return dot_cases, xdot_cases, svg_cases


def load_input_candidate_case_names(repo_root: Path) -> set[str]:
    names: set[str] = set()
    for pattern in INPUT_CANDIDATE_PATTERNS:
        for path in repo_root.glob(pattern):
            if path.is_file():
                names.add(path.stem)
    return names


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


def resolve_strict_parity_input_path(repo_root: Path, case_name: str) -> Path:
    return resolve_snapshot_input_path(repo_root, case_name)


def validate_gv_suffix_variants(repo_root: Path, manifest_set: set[str]) -> int:
    pair_count = 0
    for case_name in sorted(manifest_set):
        if not case_name.endswith(".gv"):
            continue
        base_name = case_name[: -len(".gv")]
        if base_name not in manifest_set:
            continue
        pair_count += 1
        base_input = resolve_strict_parity_input_path(repo_root, base_name)
        gv_input = resolve_strict_parity_input_path(repo_root, case_name)
        if base_input == gv_input:
            raise ValueError(
                "strict parity manifest has redundant .gv suffix pair resolving to same input: "
                f"{base_name} / {case_name} -> {base_input.relative_to(repo_root)}",
            )
    return pair_count


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    sentinel_path = resolve_path(repo_root, args.sentinel_file)
    history_path = resolve_path(repo_root, args.history_file)
    known_regression_path = resolve_path(repo_root, args.known_regression_file)
    allowed_uncovered_path = resolve_path(repo_root, args.allowed_uncovered_file)

    dot_cases, xdot_cases, svg_cases = load_manifest_case_names(repo_root)
    manifest_set = validate_manifest_alignment(dot_cases, xdot_cases, svg_cases)
    input_candidate_set = load_input_candidate_case_names(repo_root)

    sentinel_cases = load_case_names(sentinel_path)
    history_cases = load_case_names(history_path)
    known_regression_cases = load_case_names(known_regression_path)
    allowed_uncovered_cases = load_case_names(allowed_uncovered_path, allow_empty=True)
    sentinel_set = set(sentinel_cases)
    history_set = set(history_cases)
    known_regression_set = set(known_regression_cases)
    allowed_uncovered_set = set(allowed_uncovered_cases)

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
    validate_subset(
        subset_name="allowed uncovered list",
        subset_values=allowed_uncovered_set,
        superset_name="input candidate corpus",
        superset_values=input_candidate_set,
    )

    uncovered_candidates = input_candidate_set - manifest_set
    if uncovered_candidates != allowed_uncovered_set:
        extra_uncovered = sorted(uncovered_candidates - allowed_uncovered_set)
        missing_allowed = sorted(allowed_uncovered_set - uncovered_candidates)
        details: list[str] = []
        if extra_uncovered:
            details.append(
                "new uncovered cases not listed: " + ", ".join(extra_uncovered),
            )
        if missing_allowed:
            details.append(
                "listed uncovered cases no longer uncovered: " + ", ".join(missing_allowed),
            )
        raise ValueError("strict parity uncovered-input set changed: " + "; ".join(details))

    gv_suffix_pairs = validate_gv_suffix_variants(repo_root, manifest_set)

    print(
        "strict parity case lists valid: "
        "sentinel="
        f"{len(sentinel_cases)} history={len(history_cases)} "
        f"known_regression={len(known_regression_cases)} "
        f"allowed_uncovered={len(allowed_uncovered_cases)} "
        f"manifests={len(manifest_set)} candidates={len(input_candidate_set)} "
        f"gv_suffix_pairs={gv_suffix_pairs}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
