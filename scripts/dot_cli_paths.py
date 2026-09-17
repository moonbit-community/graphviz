# Copyright (c) 2026 International Digital Economy Academy
# This program is made available under the terms of the Eclipse Public License 2.0.
# SPDX-License-Identifier: EPL-2.0


"""Locate the CLI in both workspace and pre-workspace repository revisions."""

from pathlib import Path


def dot_package(repo_root: Path) -> str:
    if (repo_root / "cli/moon.mod").is_file():
        return "cli/cmd/dot"
    return "src/cmd/dot"


def dot_binary(repo_root: Path, *, release: bool = False) -> Path:
    profile = "release" if release else "debug"
    build = repo_root / "_build/native" / profile / "build"
    if (repo_root / "cli/moon.mod").is_file():
        build /= "moonbit-community/graphviz-cli"
    return build / "cmd/dot/dot.exe"
