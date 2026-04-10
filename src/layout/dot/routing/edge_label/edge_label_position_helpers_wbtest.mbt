// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "edge_label_pos_from_vnode switches between width and height based on rankdir" {
  let vnode = @edge_spline.point(30.0, 40.0)

  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::TB),
    @edge_spline.point(36.0, 40.0),
  )
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::BT),
    @edge_spline.point(36.0, 40.0),
  )
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::LR),
    @edge_spline.point(34.0, 40.0),
  )
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::RL),
    @edge_spline.point(34.0, 40.0),
  )
}

///|
test "flat_edge_label_pos_simple centers between clipped endpoints with asymmetric node widths" {
  let pos = flat_edge_label_pos_simple(
    @edge_spline.point(4.0, 10.0),
    @edge_spline.point(30.0, 10.0),
    6.0,
    5.0,
    8.0,
    6.0,
  )

  assert_point_close(pos, @edge_spline.point(17.5, 17.0))
}

///|
test "flat and vnode label position helpers keep rankdir-specific offsets" {
  let flat = flat_edge_label_pos_simple(
    @edge_spline.point(0.0, 0.0),
    @edge_spline.point(20.0, 0.0),
    3.0,
    5.0,
    8.0,
    4.0,
  )
  assert_point_close(flat, @edge_spline.point(9.0, 6.0))

  let vnode = @edge_spline.point(10.0, 20.0)
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::TB),
    @edge_spline.point(16.0, 20.0),
  )
  assert_point_close(
    edge_label_pos_from_vnode(vnode, 12.0, 8.0, @rankdir.RankDir::LR),
    @edge_spline.point(14.0, 20.0),
  )
}
