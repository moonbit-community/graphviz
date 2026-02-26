#!/usr/bin/env python3
"""Helpers for newline-delimited case list files."""

from __future__ import annotations

from pathlib import Path


def resolve_repo_path(repo_root: Path, path: Path) -> Path:
    return path if path.is_absolute() else repo_root / path


def dedupe_case_names(names: list[str]) -> list[str]:
    deduped: list[str] = []
    seen: set[str] = set()
    for name in names:
        if name in seen:
            continue
        seen.add(name)
        deduped.append(name)
    return deduped


def load_case_names(
    path: Path,
    *,
    allow_empty: bool = False,
    dedupe: bool = False,
) -> list[str]:
    names: list[str] = []
    seen: set[str] = set()
    for raw in path.read_text(encoding="utf-8").splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line in seen:
            if dedupe:
                continue
            raise ValueError(f"duplicate case in {path}: {line}")
        seen.add(line)
        names.append(line)
    if not names and not allow_empty:
        raise ValueError(f"empty case list: {path}")
    return names
