#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
worktree_path="${repo_root}/_build/local_guard/worktree"
beads_no_daemon="${BEADS_NO_DAEMON:-1}"

# Guard checks run against the staged index snapshot so local untracked/debug
# files do not pollute test discovery.
if ! git -C "${repo_root}" diff --quiet -- . ":(exclude)refs/graphviz"; then
  echo "unstaged tracked changes detected; stage all intended changes first" >&2
  exit 1
fi

tree_hash=$(git -C "${repo_root}" write-tree)
guard_commit=$(
  printf 'local guard snapshot\n' |
    git -C "${repo_root}" commit-tree "${tree_hash}" -p HEAD
)

git -C "${repo_root}" worktree prune >/dev/null 2>&1 || true

registered_worktrees=$(
  git -C "${repo_root}" worktree list --porcelain | awk '/^worktree / {print $2}'
)
has_registered_worktree=false
while IFS= read -r path; do
  if [[ "${path}" == "${worktree_path}" ]]; then
    has_registered_worktree=true
    break
  fi
done <<< "${registered_worktrees}"

if [[ "${has_registered_worktree}" == "true" && ! -e "${worktree_path}/.git" ]]; then
  git -C "${repo_root}" worktree remove --force "${worktree_path}" >/dev/null 2>&1 || true
  has_registered_worktree=false
fi

if [[ "${has_registered_worktree}" == "false" ]]; then
  rm -rf "${worktree_path}"
  mkdir -p "$(dirname "${worktree_path}")"
  BEADS_NO_DAEMON="${beads_no_daemon}" \
    git -C "${repo_root}" worktree add --detach "${worktree_path}" "${guard_commit}" >/dev/null
else
  BEADS_NO_DAEMON="${beads_no_daemon}" \
    git -C "${worktree_path}" reset --hard "${guard_commit}" >/dev/null
  if [[ "${LOCAL_GUARD_PRISTINE:-0}" == "1" ]]; then
    BEADS_NO_DAEMON="${beads_no_daemon}" \
      git -C "${worktree_path}" clean -ffd >/dev/null
  else
    # Keep _build cache between guard runs for faster iterative refactors.
    BEADS_NO_DAEMON="${beads_no_daemon}" \
      git -C "${worktree_path}" clean -ffd -e _build/ >/dev/null
  fi
fi

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
  scripts/run_moon_test_full.sh
)
