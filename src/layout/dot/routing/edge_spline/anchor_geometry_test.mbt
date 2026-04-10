// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "port side helpers and endpoint slope" {
  let size = @node_primitives.node_size_from_points(100.0, 50.0)
  let pos = point(10.0, 20.0)
  let rect = port_side_rect(pos, size)
  assert_eq(rect, { llx: -40.0, lly: -5.0, urx: 60.0, ury: 45.0 })
  assert_eq(port_side_count(rect, pos, size), 4)
  let port_rect : @geom.Rect = {
    llx: rect.llx,
    lly: rect.lly + 1.0,
    urx: rect.llx + 5.0,
    ury: rect.ury - 1.0,
  }
  assert_eq(port_side_count(port_rect, pos, size), 1)
  let slope = endpoint_slope_for_anchor(
    None,
    0,
    point(0.0, 0.0),
    pos,
    size,
    point(10.0, 0.0),
    @rankdir.RankDir::TB,
    true,
    None,
  )
  assert_eq(slope, { x: 0.0, y: 0.0 })
}
