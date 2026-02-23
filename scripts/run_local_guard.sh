#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

# Guard checks run against the staged index snapshot so local untracked/debug
# files do not pollute test discovery.
if ! git -C "${repo_root}" diff --quiet -- . ":(exclude)refs/graphviz"; then
  echo "unstaged tracked changes detected; stage all intended changes first" >&2
  exit 1
fi

tmp_root=$(mktemp -d /tmp/graphviz_local_guard.XXXXXX)
cleanup() {
  if [[ -n "${worktree_path:-}" ]]; then
    git -C "${repo_root}" worktree remove --force "${worktree_path}" >/dev/null 2>&1 || true
  fi
  python3 - "${tmp_root}" <<'PY'
import shutil
import sys
shutil.rmtree(sys.argv[1], ignore_errors=True)
PY
}
trap cleanup EXIT

tree_hash=$(git -C "${repo_root}" write-tree)
guard_commit=$(
  printf 'local guard snapshot\n' |
    git -C "${repo_root}" commit-tree "${tree_hash}" -p HEAD
)

worktree_path="${tmp_root}/worktree"
git -C "${repo_root}" worktree add --detach "${worktree_path}" "${guard_commit}" >/dev/null

submodule_args=(submodule update --init refs/graphviz)
if [[ -e "${repo_root}/refs/graphviz/.git" || -d "${repo_root}/refs/graphviz/objects" ]]; then
  submodule_args=(
    submodule
    update
    --init
    --reference
    "${repo_root}/refs/graphviz"
    refs/graphviz
  )
fi
GIT_TERMINAL_PROMPT=0 git -C "${worktree_path}" "${submodule_args[@]}" >/dev/null

(
  cd "${worktree_path}"
  moon build src/cmd/dot --target native
  scripts/check_strict_parity.py --formats dot xdot svg --focus ldbxtried typeshar
  scripts/check_strict_parity.py --formats dot xdot svg
)
