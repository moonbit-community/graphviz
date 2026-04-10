// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "detour_polyline_for_rects chooses the left detour lane for top-bottom routing when shorter" {
  let tail_rect : @geom.Rect = { llx: 0.0, lly: -10.0, urx: 10.0, ury: 10.0 }
  let head_rect : @geom.Rect = { llx: 20.0, lly: 30.0, urx: 30.0, ury: 50.0 }

  let points = detour_polyline_for_rects({
    tail: @edge_spline.point(0.0, 0.0),
    head: @edge_spline.point(20.0, 40.0),
    tail_rect,
    head_rect,
    nodesep_pt: 8.0,
    rankdir: RankDir::TB,
  })

  assert_eq(points.length(), 6)
  assert_eq(points[0], @edge_spline.point(0.0, 0.0))
  assert_eq(points[1], @edge_spline.point(0.0, 26.0))
  assert_eq(points[2], @edge_spline.point(-8.0, 26.0))
  assert_eq(points[3], @edge_spline.point(-8.0, 55.71))
  assert_eq(points[4], @edge_spline.point(20.0, 55.71))
  assert_eq(points[5], @edge_spline.point(20.0, 40.0))
}

///|
test "detour_polyline_for_rects chooses the lower detour lane for left-right routing when tied" {
  let tail_rect : @geom.Rect = { llx: -2.0, lly: 0.0, urx: 2.0, ury: 10.0 }
  let head_rect : @geom.Rect = { llx: 38.0, lly: 10.0, urx: 42.0, ury: 20.0 }

  let points = detour_polyline_for_rects({
    tail: @edge_spline.point(0.0, 5.0),
    head: @edge_spline.point(40.0, 15.0),
    tail_rect,
    head_rect,
    nodesep_pt: 8.0,
    rankdir: RankDir::LR,
  })

  assert_eq(points.length(), 6)
  assert_eq(points[0], @edge_spline.point(0.0, 5.0))
  assert_eq(points[1], @edge_spline.point(18.0, 5.0))
  assert_eq(points[2], @edge_spline.point(18.0, -8.0))
  assert_eq(points[3], @edge_spline.point(47.71, -8.0))
  assert_eq(points[4], @edge_spline.point(47.71, 15.0))
  assert_eq(points[5], @edge_spline.point(40.0, 15.0))
}
