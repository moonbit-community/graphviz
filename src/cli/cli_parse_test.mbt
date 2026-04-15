// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "parse cli args uses stdin when input missing" {
  let action = parse_cli_args(["-Tdot"])
  guard action is CliAction::Render(job) else { fail("expected render action") }
  assert_eq(job.input, None)
}

///|
test "parse cli args uses stdin for dash input" {
  let action = parse_cli_args(["-Tdot", "-"])
  guard action is CliAction::Render(job) else { fail("expected render action") }
  assert_eq(job.input, Some("-"))
}

///|
test "parse cli args resolves engine from program name" {
  let action = parse_cli_args([], program="neato")
  guard action is CliAction::Render(job) else { fail("expected render action") }
  assert_eq(job.engine, LayoutEngine::Neato)
  assert_eq(job.engine_explicit, false)
}

///|
test "parse cli args -K overrides program engine" {
  let action = parse_cli_args(["-Kdot"], program="neato")
  guard action is CliAction::Render(job) else { fail("expected render action") }
  assert_eq(job.engine, LayoutEngine::Dot)
  assert_eq(job.engine_explicit, true)
}
