// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "should_capture_xpos_snapshot follows env value and graph name matching" {
  let env_key = "DOT_CAPTURE_XPOS_CONSTRAINTS"
  let original = @sys.get_env_var(env_key)
  let named = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    name="capture-me",
    strict=false,
  )
  let anonymous = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)

  @sys.unset_env_var(env_key)
  let absent_named = should_capture_xpos_snapshot(named)
  let absent_anonymous = should_capture_xpos_snapshot(anonymous)

  @sys.set_env_var(env_key, "")
  let empty_named = should_capture_xpos_snapshot(named)

  @sys.set_env_var(env_key, "1")
  let one_named = should_capture_xpos_snapshot(named)
  let one_anonymous = should_capture_xpos_snapshot(anonymous)

  @sys.set_env_var(env_key, "capture-me")
  let exact_named = should_capture_xpos_snapshot(named)
  let exact_anonymous = should_capture_xpos_snapshot(anonymous)

  @sys.set_env_var(env_key, "other-graph")
  let mismatch_named = should_capture_xpos_snapshot(named)

  match original {
    Some(value) => @sys.set_env_var(env_key, value)
    None => @sys.unset_env_var(env_key)
  }

  assert_false(absent_named)
  assert_false(absent_anonymous)
  assert_true(empty_named)
  assert_true(one_named)
  assert_true(one_anonymous)
  assert_true(exact_named)
  assert_false(exact_anonymous)
  assert_false(mismatch_named)
}
