// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "arrow ownership follows markers rather than spline list endpoints" {
  let tip : @geom.Point = { x: 10.0, y: 20.0, }
  let with_head : @geom.Spline = { start: None, end: Some(tip), points: [tip], }
  let interior : @geom.Spline = { start: None, end: None, points: [tip], }
  @test.assert_eq(
    spline_with_arrow([with_head, interior], true),
    Some(with_head),
  )
  @test.assert_eq(spline_with_arrow([interior], true), None)
  @test.assert_eq(spline_with_arrow([with_head, interior], false), None)
}
