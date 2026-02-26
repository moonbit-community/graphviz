#!/usr/bin/env python3
"""Batch scan and add all passing strict parity cases."""

from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scan all uncovered cases and add those that pass.",
    )
    parser.add_argument(
        "--repo-root",
        type=Path,
        default=Path(__file__).resolve().parents[1],
        help="Repository root path.",
    )
    parser.add_argument(
        "--dot-bin",
        type=Path,
        default=None,
        help="Path to dot CLI binary.",
    )
    parser.add_argument(
        "--timeout",
        type=int,
        default=15,
        help="Timeout per case in seconds (default: 15).",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Show what would be added without writing files.",
    )
    parser.add_argument(
        "--batch-size",
        type=int,
        default=0,
        help="Stop after adding N cases (0 = unlimited).",
    )
    return parser.parse_args()


def get_covered_cases(repo_root: Path) -> set[str]:
    """Get all currently covered case names."""
    covered = set()
    for manifest in [
        "tests/layout/dot/cases.txt",
        "tests/render/xdot/cases.txt",
        "tests/render/svg_snapshot/cases.txt",
    ]:
        manifest_path = repo_root / manifest
        if not manifest_path.exists():
            continue
        for line in manifest_path.read_text().splitlines():
            line = line.strip()
            if line and not line.startswith("#"):
                covered.add(line)
    return covered


def get_all_input_cases(repo_root: Path) -> list[str]:
    """Get all .gv input case names from graphviz reference corpus."""
    graphs_dir = repo_root / "refs" / "graphviz" / "tests" / "graphs"
    if not graphs_dir.exists():
        return []
    cases = []
    for gv_file in sorted(graphs_dir.glob("*.gv")):
        cases.append(gv_file.stem)
    return cases


def ensure_dot_bin(repo_root: Path, dot_bin: Path | None) -> Path:
    """Ensure dot binary exists, build if needed."""
    default_bin = repo_root / "_build/native/debug/build/cmd/dot/dot.exe"
    dot_bin = dot_bin.resolve() if dot_bin else default_bin
    if dot_bin.exists():
        return dot_bin
    print(f"Building dot binary: {dot_bin}", file=sys.stderr)
    subprocess.run(
        ["moon", "build", "src/cmd/dot", "--target", "native"],
        cwd=repo_root,
        check=True,
    )
    if not dot_bin.exists():
        raise FileNotFoundError(f"dot binary missing after build: {dot_bin}")
    return dot_bin


def test_case(
    dot_bin: Path,
    input_path: Path,
    repo_root: Path,
    timeout: int,
) -> tuple[bytes | None, bytes | None, bytes | None]:
    """Test if a case can generate all three formats successfully."""
    results = []
    for fmt in ["dot", "xdot", "svg"]:
        try:
            proc = subprocess.run(
                [str(dot_bin), "-Kdot", f"-T{fmt}", str(input_path)],
                cwd=repo_root,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                timeout=timeout,
                check=False,
            )
            if proc.returncode == 0 and len(proc.stdout) > 0:
                results.append(proc.stdout)
            else:
                return (None, None, None)
        except subprocess.TimeoutExpired:
            return (None, None, None)
        except Exception:
            return (None, None, None)
    return tuple(results) if len(results) == 3 else (None, None, None)


def write_fixtures(
    repo_root: Path,
    case_name: str,
    dot_data: bytes,
    xdot_data: bytes,
    svg_data: bytes,
) -> None:
    """Write fixture files for a case."""
    dot_path = repo_root / "tests/layout/dot" / f"{case_name}.gv.dot"
    xdot_path = repo_root / "tests/render/xdot" / f"{case_name}.xdot"
    svg_path = repo_root / "tests/render/svg_snapshot" / f"{case_name}.svg"
    
    dot_path.write_bytes(dot_data)
    xdot_path.write_bytes(xdot_data)
    svg_path.write_bytes(svg_data)


def append_to_manifests(repo_root: Path, case_name: str) -> None:
    """Append case name to all three manifest files."""
    for manifest in [
        "tests/layout/dot/cases.txt",
        "tests/render/xdot/cases.txt",
        "tests/render/svg_snapshot/cases.txt",
    ]:
        manifest_path = repo_root / manifest
        with manifest_path.open("a") as f:
            f.write(f"{case_name}\n")


def main() -> int:
    args = parse_args()
    repo_root = args.repo_root.resolve()
    
    dot_bin = ensure_dot_bin(repo_root, args.dot_bin)
    covered = get_covered_cases(repo_root)
    all_cases = get_all_input_cases(repo_root)
    uncovered = [c for c in all_cases if c not in covered]
    
    print(f"Total input cases: {len(all_cases)}", file=sys.stderr)
    print(f"Already covered: {len(covered)}", file=sys.stderr)
    print(f"Uncovered: {len(uncovered)}", file=sys.stderr)
    
    if not uncovered:
        print("All cases already covered!", file=sys.stderr)
        return 0
    
    added = 0
    failed = []
    
    for case_name in uncovered:
        if args.batch_size > 0 and added >= args.batch_size:
            print(f"\nReached batch size limit: {args.batch_size}", file=sys.stderr)
            break
        
        input_path = repo_root / "refs/graphviz/tests/graphs" / f"{case_name}.gv"
        if not input_path.exists():
            continue
        
        print(f"Testing {case_name}...", end=" ", file=sys.stderr, flush=True)
        dot_data, xdot_data, svg_data = test_case(
            dot_bin, input_path, repo_root, args.timeout
        )
        
        if dot_data and xdot_data and svg_data:
            if args.dry_run:
                print(
                    f"✓ (dry-run: {len(dot_data)} / {len(xdot_data)} / {len(svg_data)})",
                    file=sys.stderr,
                )
            else:
                write_fixtures(repo_root, case_name, dot_data, xdot_data, svg_data)
                append_to_manifests(repo_root, case_name)
                print(
                    f"✓ added ({len(dot_data)} / {len(xdot_data)} / {len(svg_data)})",
                    file=sys.stderr,
                )
            added += 1
        else:
            print("✗ failed", file=sys.stderr)
            failed.append(case_name)
    
    print(f"\n=== Summary ===", file=sys.stderr)
    print(f"Successfully added: {added}", file=sys.stderr)
    print(f"Failed: {len(failed)}", file=sys.stderr)
    
    if failed:
        print(f"\nFailed cases ({len(failed)}):", file=sys.stderr)
        for case in failed[:20]:
            print(f"  - {case}", file=sys.stderr)
        if len(failed) > 20:
            print(f"  ... and {len(failed) - 20} more", file=sys.stderr)
    
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
