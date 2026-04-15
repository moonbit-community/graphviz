// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "parse_splines accepts graphviz aliases" {
  assert_eq(parse_splines("true"), Some(SplinesMode::Spline))
  assert_eq(parse_splines("line"), Some(SplinesMode::Polyline))
  assert_eq(parse_splines(""), Some(SplinesMode::None))
  assert_eq(parse_splines("ortho"), Some(SplinesMode::Ortho))
  assert_eq(parse_splines("curved"), Some(SplinesMode::Curved))
  assert_eq(parse_splines("bogus"), None)
}
