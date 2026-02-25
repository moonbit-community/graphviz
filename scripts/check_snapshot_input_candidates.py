#!/usr/bin/env python3
"""Validate snapshot input candidate lists stay aligned across tests/guards."""

from __future__ import annotations

import argparse
import ast
import re
from pathlib import Path


def normalize_candidate_template(candidate: str) -> str:
    return (
        candidate.replace("${case_name}", "{case}")
        .replace("${case}", "{case}")
        .replace(r"\{case_name}", "{case}")
        .replace("{case_name}", "{case}")
        .replace(r"\{case}", "{case}")
    )


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Check snapshot input candidate list alignment across files.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root path (default: inferred from script path).",
    )
    return parser.parse_args()


def parse_python_string_list(path: Path, variable_name: str) -> list[str]:
    tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
    for node in tree.body:
        if not isinstance(node, ast.Assign):
            continue
        for target in node.targets:
            if isinstance(target, ast.Name) and target.id == variable_name:
                value = node.value
                if not isinstance(value, (ast.List, ast.Tuple)):
                    raise ValueError(f"{path}: {variable_name} is not a list/tuple")
                items: list[str] = []
                for elt in value.elts:
                    if not isinstance(elt, ast.Constant) or not isinstance(elt.value, str):
                        raise ValueError(
                            f"{path}: {variable_name} contains non-string literal",
                        )
                    items.append(elt.value)
                if not items:
                    raise ValueError(f"{path}: {variable_name} is empty")
                return [normalize_candidate_template(item) for item in items]
    raise ValueError(f"{path}: missing variable {variable_name}")


def parse_mbt_candidates(path: Path) -> list[str]:
    lines = path.read_text(encoding="utf-8").splitlines()
    in_block = False
    items: list[str] = []
    for raw in lines:
        if not in_block:
            if "let candidates : Array[String] = [" in raw:
                in_block = True
            continue
        stripped = raw.strip()
        if stripped == "]":
            if not items:
                raise ValueError(f"{path}: empty candidates list")
            return items
        match = re.fullmatch(r'"([^"]+)",?', stripped)
        if match is None:
            raise ValueError(f"{path}: unexpected candidates entry: {stripped}")
        items.append(normalize_candidate_template(match.group(1)))
    raise ValueError(f"{path}: unterminated candidates list")


def ensure_file_contains(path: Path, snippet: str) -> None:
    content = path.read_text(encoding="utf-8")
    if snippet not in content:
        raise ValueError(f"{path}: missing required snippet: {snippet}")


def format_mismatch(reference: list[str], current: list[str]) -> str:
    ref_set = set(reference)
    cur_set = set(current)
    missing = sorted(ref_set - cur_set)
    extra = sorted(cur_set - ref_set)
    parts: list[str] = []
    if missing:
        parts.append("missing=" + ",".join(missing))
    if extra:
        parts.append("extra=" + ",".join(extra))
    if not parts and len(reference) == len(current):
        for idx, (left, right) in enumerate(zip(reference, current)):
            if left != right:
                parts.append(
                    f"order_diff@index={idx}: expected={left} actual={right}",
                )
                break
    if not parts:
        parts.append(f"length_diff expected={len(reference)} actual={len(current)}")
    return "; ".join(parts)


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()

    canonical_path = repo_root / "scripts/snapshot_inputs.py"
    canonical = parse_python_string_list(canonical_path, "INPUT_CANDIDATES")

    ensure_file_contains(
        repo_root / "scripts/check_strict_parity.py",
        "from snapshot_inputs import INPUT_CANDIDATES, resolve_input_path",
    )
    ensure_file_contains(
        repo_root / "scripts/check_capture_env_invariance.py",
        "from snapshot_inputs import INPUT_CANDIDATES, resolve_input_path",
    )
    ensure_file_contains(
        repo_root / "scripts/check_strict_parity_case_lists.py",
        "from snapshot_inputs import INPUT_CANDIDATES as STRICT_PARITY_INPUT_CANDIDATES",
    )
    for script_name in (
        "generate_dot_snapshots.sh",
        "generate_xdot_snapshots.sh",
        "generate_svg_renderer_snapshots.sh",
        "generate_svg_snapshots.sh",
    ):
        ensure_file_contains(
            repo_root / "scripts" / script_name,
            'python3 "${repo_root}/scripts/snapshot_inputs.py" --repo-root "${repo_root}" --case "${case_name}"',
        )

    targets: list[tuple[str, list[str]]] = []
    targets.append(
        (
            "src/layout/dot/snapshot_test.mbt:candidates",
            parse_mbt_candidates(repo_root / "src/layout/dot/snapshot_test.mbt"),
        )
    )
    targets.append(
        (
            "src/render/xdot/snapshot_test.mbt:candidates",
            parse_mbt_candidates(repo_root / "src/render/xdot/snapshot_test.mbt"),
        )
    )
    targets.append(
        (
            "src/render/svg/svg_test.mbt:candidates",
            parse_mbt_candidates(repo_root / "src/render/svg/svg_test.mbt"),
        )
    )
    mismatches: list[str] = []
    for name, current in targets:
        if current != canonical:
            mismatches.append(f"{name}: {format_mismatch(canonical, current)}")

    if mismatches:
        details = "\n".join(mismatches)
        raise ValueError(
            "snapshot input candidate lists are out of sync with "
            "scripts/check_strict_parity.py INPUT_CANDIDATES:\n" + details,
        )

    print(
        "snapshot input candidate lists aligned: "
        f"canonical_count={len(canonical)} targets={len(targets)}",
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
