#!/usr/bin/env bash
set -euo pipefail

repo_root=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
default_jobs=$(
  getconf _NPROCESSORS_ONLN 2>/dev/null ||
    sysctl -n hw.ncpu 2>/dev/null ||
    echo 8
)
moon_jobs="${MOON_TEST_JOBS:-${default_jobs}}"
capture_jobs="${CAPTURE_ENV_INVARIANCE_JOBS:-${moon_jobs}}"
strict_parity_jobs="${STRICT_PARITY_JOBS:-${moon_jobs}}"
cc_wrapper="${repo_root}/scripts/moon_cc_wrapper.sh"
emit_timing="${LOCAL_GUARD_TIMING:-0}"
use_frozen="${LOCAL_GUARD_FROZEN:-1}"
sanitize_dot_env="${LOCAL_GUARD_SANITIZE_DOT_ENV:-1}"
script_args=("$@")
has_cached_modules=0
if [[ -f "${repo_root}/.mooncakes/moonbitlang/x/moon.mod.json" ]]; then
  has_cached_modules=1
fi

run_step() {
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

run_moon_command_with_optional_frozen() {
  local fallback_label="$1"
  shift
  local cmd=("$@")
  if [[ "${use_frozen}" == "1" && "${has_cached_modules}" == "1" ]]; then
    if "${cmd[@]}" --frozen; then
      return
    fi
    echo "[local-guard] ${fallback_label}: retry without --frozen" >&2
  fi
  "${cmd[@]}"
}

run_moon_test_command() {
  local cmd=(moon test --target native --release --deny-warn -j "${moon_jobs}")
  if [[ ${#script_args[@]} -gt 0 ]]; then
    run_moon_command_with_optional_frozen "moon test fallback" "${cmd[@]}" "${script_args[@]}"
  else
    run_moon_command_with_optional_frozen "moon test fallback" "${cmd[@]}"
  fi
}

run_moon_build_dot_command() {
  run_moon_command_with_optional_frozen \
    "moon build fallback" \
    moon build src/cmd/dot --target native --release -j "${moon_jobs}"
}

run_strict_parity_command() {
  scripts/check_strict_parity.py \
    --dot-bin "${dot_bin}" \
    --formats dot xdot svg \
    --jobs "${strict_parity_jobs}"
}

sanitize_dot_runtime_env() {
  if [[ "${sanitize_dot_env}" != "1" ]]; then
    return
  fi
  while IFS='=' read -r key _; do
    if [[ "${key}" == DOT_* ]]; then
      if [[ "${key}" == "DOT_WRITE_PARITY_ARTIFACTS" ]]; then
        continue
      fi
      unset "${key}"
    fi
  done < <(env)
}

if [[ "${LOCAL_GUARD_SUPPRESS_CLANG_EXIT_WARNING:-1}" == "1" &&
  -z "${MOON_CC:-}" &&
  -x "${cc_wrapper}" ]]; then
  host_cc=$(command -v clang 2>/dev/null || command -v cc 2>/dev/null || true)
  host_ar=$(command -v ar 2>/dev/null || true)
  if [[ -n "${host_cc}" ]]; then
    export MOON_CC="${cc_wrapper}"
    export MOON_CC_REAL="${host_cc}"
    if [[ -z "${MOON_AR:-}" && -n "${host_ar}" ]]; then
      export MOON_AR="${host_ar}"
    fi
  fi
fi

cd "${repo_root}"
sanitize_dot_runtime_env
run_step "moon test" run_moon_test_command

run_step "check snapshot inputs" scripts/check_snapshot_input_candidates.py
run_step "check strict parity lists" scripts/check_strict_parity_case_lists.py

run_step "moon build dot" run_moon_build_dot_command
dot_bin="_build/native/release/build/cmd/dot/dot.exe"

run_step "check strict parity" run_strict_parity_command

run_step "capture env invariance" scripts/check_capture_env_invariance.py \
  --dot-bin "${dot_bin}" \
  --formats dot xdot svg \
  --jobs "${capture_jobs}" \
  --cases-file tests/capture_env_invariant_cases.txt
