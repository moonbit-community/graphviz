// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "env_flag_enabled respects explicit false tokens and otherwise falls back or enables" {
  assert_true(env_flag_enabled(None, true))
  assert_false(env_flag_enabled(None, false))

  assert_false(env_flag_enabled(Some("0"), true))
  assert_false(env_flag_enabled(Some("FALSE"), true))
  assert_false(env_flag_enabled(Some("No"), true))

  assert_true(env_flag_enabled(Some("1"), false))
  assert_true(env_flag_enabled(Some("true"), false))
  assert_true(env_flag_enabled(Some("yes"), false))
  assert_true(env_flag_enabled(Some("unexpected"), false))
  assert_true(env_flag_enabled(Some(""), false))
}

///|
test "env_flag_enabled_nonempty also treats empty strings as disabled" {
  assert_false(env_flag_enabled_nonempty(None))
  assert_false(env_flag_enabled_nonempty(Some("")))
  assert_false(env_flag_enabled_nonempty(Some("0")))
  assert_false(env_flag_enabled_nonempty(Some("false")))
  assert_false(env_flag_enabled_nonempty(Some("NO")))

  assert_true(env_flag_enabled_nonempty(Some("1")))
  assert_true(env_flag_enabled_nonempty(Some("true")))
  assert_true(env_flag_enabled_nonempty(Some("yes")))
  assert_true(env_flag_enabled_nonempty(Some("enabled")))
}
