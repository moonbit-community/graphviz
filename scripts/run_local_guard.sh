#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
worktree_path="${repo_root}/_build/local_guard/worktree"
emit_timing="${LOCAL_GUARD_TIMING:-0}"
guard_started_at=${SECONDS}
guard_cache_dir="${repo_root}/_build/local_guard"
guard_cache_key_file="${guard_cache_dir}/last_success_key.txt"
cache_enabled="${LOCAL_GUARD_CACHE:-1}"

run_guard_step() {
  local label="$1"
  shift
  if [[ "${emit_timing}" == "1" ]]; then
    local started_at=${SECONDS}
    "$@"
    local elapsed=$((SECONDS - started_at))
    echo "[local-guard] ${label}: ${elapsed}s"
  else
    "$@"
  fi
}

run_moon_test_full_in_worktree() {
  (
    cd "${worktree_path}"
    scripts/run_moon_test_full.sh
  )
}

# Guard checks run against the staged index snapshot so local untracked/debug
# files do not pollute test discovery.
if ! git -C "${repo_root}" diff --quiet -- . ":(exclude)refs/graphviz"; then
  echo "unstaged tracked changes detected; stage all intended changes first" >&2
  exit 1
fi

tree_hash=$(git -C "${repo_root}" write-tree)
moon_version=$(moon --version 2>/dev/null || echo "unknown")
guard_cache_key="${tree_hash}|${moon_version}"

if [[ "${cache_enabled}" == "1" &&
  "${LOCAL_GUARD_FORCE:-0}" != "1" &&
  "${LOCAL_GUARD_PRISTINE:-0}" != "1" &&
  "${emit_timing}" != "1" &&
  -f "${guard_cache_key_file}" ]]; then
  cached_key=$(cat "${guard_cache_key_file}")
  if [[ "${cached_key}" == "${guard_cache_key}" ]]; then
    echo "[local-guard] cache hit (same tree + moon version); skipping rerun"
    exit 0
  fi
fi

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
  git -c core.hooksPath=/dev/null -C "${repo_root}" worktree remove --force "${worktree_path}" >/dev/null 2>&1 || true
  has_registered_worktree=false
fi

if [[ "${has_registered_worktree}" == "false" ]]; then
  rm -rf "${worktree_path}"
  mkdir -p "$(dirname "${worktree_path}")"
  run_guard_step "worktree add" git -c core.hooksPath=/dev/null -C "${repo_root}" worktree add --detach "${worktree_path}" "${guard_commit}" >/dev/null
else
  run_guard_step "worktree reset" git -c core.hooksPath=/dev/null -C "${worktree_path}" reset --hard "${guard_commit}" >/dev/null
  if [[ "${LOCAL_GUARD_PRISTINE:-0}" == "1" ]]; then
    run_guard_step "worktree clean pristine" git -c core.hooksPath=/dev/null -C "${worktree_path}" clean -ffd >/dev/null
  else
    # Keep heavy caches between guard runs for faster iterative refactors.
    run_guard_step "worktree clean cached" git -c core.hooksPath=/dev/null -C "${worktree_path}" clean -ffd \
      -e _build/ \
      -e .mooncakes/ \
      -e refs/graphviz/ >/dev/null
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
should_sync_submodule=true
if [[ "${LOCAL_GUARD_SUBMODULE_CHECK:-1}" == "1" ]]; then
  expected_submodule_commit=$(git -C "${worktree_path}" rev-parse HEAD:refs/graphviz 2>/dev/null || true)
  current_submodule_commit=""
  if [[ -n "${expected_submodule_commit}" && -e "${worktree_path}/refs/graphviz/.git" ]]; then
    current_submodule_commit=$(git -C "${worktree_path}/refs/graphviz" rev-parse HEAD 2>/dev/null || true)
  fi
  if [[ -n "${expected_submodule_commit}" &&
    "${expected_submodule_commit}" == "${current_submodule_commit}" ]]; then
    should_sync_submodule=false
  fi
fi

if [[ "${should_sync_submodule}" == "true" ]]; then
  run_guard_step "submodule update" env GIT_TERMINAL_PROMPT=0 git -C "${worktree_path}" "${submodule_args[@]}" >/dev/null
else
  if [[ "${emit_timing}" == "1" ]]; then
    echo "[local-guard] submodule update: 0s (up-to-date)"
  fi
fi

run_guard_step "run moon test full" run_moon_test_full_in_worktree

if [[ "${emit_timing}" == "1" ]]; then
  guard_elapsed=$((SECONDS - guard_started_at))
  echo "[local-guard] total: ${guard_elapsed}s"
fi

mkdir -p "${guard_cache_dir}"
printf '%s' "${guard_cache_key}" > "${guard_cache_key_file}"
