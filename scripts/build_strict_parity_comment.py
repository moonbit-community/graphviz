#!/usr/bin/env python3
"""Build a PR comment body from strict parity JSON report."""

from __future__ import annotations

import argparse
import json
from pathlib import Path


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Build strict parity markdown comment from report JSON.",
    )
    parser.add_argument(
        "--report",
        type=Path,
        required=True,
        help="Path to strict parity report JSON.",
    )
    parser.add_argument(
        "--run-url",
        type=str,
        required=True,
        help="GitHub Actions run URL.",
    )
    parser.add_argument(
        "--artifact-name",
        type=str,
        required=True,
        help="Uploaded artifact name.",
    )
    parser.add_argument(
        "--max-list",
        type=int,
        default=30,
        help="Maximum mismatched case names to list per format.",
    )
    return parser.parse_args()


def build_missing_report_comment(report_path: Path, run_url: str) -> str:
    return "\n".join(
        [
            "<!-- strict-parity-report -->",
            "### Strict Parity Report",
            "",
            "⚠️ strict parity report file is missing.",
            "",
            f"- expected report: `{report_path}`",
            f"- run: {run_url}",
            "",
            "The job likely failed before the full parity step finished.",
            "",
        ]
    )


def build_comment(
    report_path: Path,
    run_url: str,
    artifact_name: str,
    max_list: int,
) -> str:
    if not report_path.exists():
        return build_missing_report_comment(report_path, run_url)
    raw = report_path.read_text(encoding="utf-8")
    data = json.loads(raw)
    results = data.get("results", [])
    had_mismatch = bool(data.get("had_mismatch"))
    title = "❌ Strict Parity Failed" if had_mismatch else "✅ Strict Parity Passed"

    lines: list[str] = [
        "<!-- strict-parity-report -->",
        "### Strict Parity Report",
        "",
        title,
        "",
        "| Format | Total | Mismatches |",
        "| --- | ---: | ---: |",
    ]
    for entry in results:
        fmt = str(entry.get("format", "unknown"))
        total = int(entry.get("total", 0))
        mismatch_count = int(entry.get("mismatch_count", 0))
        lines.append(f"| `{fmt}` | {total} | {mismatch_count} |")

    lines.extend(
        [
            "",
            f"- run: {run_url}",
            f"- artifact: `{artifact_name}`",
            "",
        ]
    )

    for entry in results:
        mismatch_count = int(entry.get("mismatch_count", 0))
        if mismatch_count == 0:
            continue
        fmt = str(entry.get("format", "unknown"))
        mismatches = [str(x) for x in entry.get("mismatches", [])]
        artifact_entries = entry.get("mismatch_artifacts", [])
        diff_paths: list[str] = []
        if isinstance(artifact_entries, list):
            for artifact in artifact_entries:
                if not isinstance(artifact, dict):
                    continue
                diff_path = artifact.get("diff_path")
                if diff_path is None:
                    continue
                diff_paths.append(str(diff_path))
        listed = mismatches[:max_list]
        hidden_count = max(0, len(mismatches) - len(listed))
        lines.append(f"<details><summary>{fmt} mismatches ({mismatch_count})</summary>")
        lines.append("")
        lines.append("```text")
        if listed:
            lines.append(" ".join(listed))
        else:
            lines.append("(none)")
        if hidden_count > 0:
            lines.append(f"... and {hidden_count} more")
        lines.append("```")
        if diff_paths:
            path_listed = diff_paths[:5]
            hidden_path_count = max(0, len(diff_paths) - len(path_listed))
            lines.append("")
            lines.append("diff files:")
            lines.append("```text")
            lines.extend(path_listed)
            if hidden_path_count > 0:
                lines.append(f"... and {hidden_path_count} more")
            lines.append("```")
        lines.append("</details>")
        lines.append("")

    return "\n".join(lines)


def main() -> int:
    args = parse_args()
    comment = build_comment(
        report_path=args.report,
        run_url=args.run_url,
        artifact_name=args.artifact_name,
        max_list=max(1, args.max_list),
    )
    print(comment)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
