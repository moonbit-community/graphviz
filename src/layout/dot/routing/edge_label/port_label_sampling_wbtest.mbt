// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "port_label_points respects marker fallback semantics" {
  let spline = straight_spline_with_markers()

  let head_marker = require_point_with_tangent(
    port_label_points(spline, true, true),
    "head-marker",
  )
  assert_point_close(head_marker.pos, @edge_spline.point(10.0, 0.0))
  assert_point_close(head_marker.tangent, @edge_spline.point(9.0, 0.0))

  let head_bezier = require_point_with_tangent(
    port_label_points(spline, true, false),
    "head-bezier",
  )
  assert_point_close(head_bezier.pos, @edge_spline.point(9.0, 0.0))
  assert_point_close(
    head_bezier.tangent,
    @edge_spline.point(8.1, 0.0),
    eps=0.01,
  )

  let tail_marker = require_point_with_tangent(
    port_label_points(spline, false, true),
    "tail-marker",
  )
  assert_point_close(tail_marker.pos, @edge_spline.point(-1.0, 0.0))
  assert_point_close(tail_marker.tangent, @edge_spline.point(0.0, 0.0))

  let tail_bezier = require_point_with_tangent(
    port_label_points(spline, false, false),
    "tail-bezier",
  )
  assert_point_close(tail_bezier.pos, @edge_spline.point(0.0, 0.0))
  assert_point_close(
    tail_bezier.tangent,
    @edge_spline.point(0.9, 0.0),
    eps=0.01,
  )
}

///|
test "port_label_points falls back to bezier samples when markers are requested but missing" {
  let spline = straight_spline()

  let head = require_point_with_tangent(
    port_label_points(spline, true, true),
    "head-fallback",
  )
  assert_point_close(head.pos, @edge_spline.point(9.0, 0.0))
  assert_point_close(head.tangent, @edge_spline.point(8.1, 0.0), eps=0.01)

  let tail = require_point_with_tangent(
    port_label_points(spline, false, true),
    "tail-fallback",
  )
  assert_point_close(tail.pos, @edge_spline.point(0.0, 0.0))
  assert_point_close(tail.tangent, @edge_spline.point(0.9, 0.0), eps=0.01)
}
