// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "record_layout_orientation flips only LR and RL rank directions" {
  assert_true(
    record_layout_orientation(@rankdir.RankDir::TB)
    is RecordOrientation::Horizontal,
  )
  assert_true(
    record_layout_orientation(@rankdir.RankDir::BT)
    is RecordOrientation::Horizontal,
  )
  assert_true(
    record_layout_orientation(@rankdir.RankDir::LR)
    is RecordOrientation::Vertical,
  )
  assert_true(
    record_layout_orientation(@rankdir.RankDir::RL)
    is RecordOrientation::Vertical,
  )
}

///|
test "merge_sizes_with_vnodes overlays vnode sizes without dropping base sizes" {
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.node_size_from_points(10.0, 20.0)
  sizes["b"] = @node_primitives.node_size_from_points(30.0, 40.0)

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["b"] = @node_primitives.node_size_from_points(50.0, 60.0)
  vnode_sizes["v1"] = @node_primitives.node_size_from_points(70.0, 80.0)

  let merged = merge_sizes_with_vnodes(sizes, vnode_sizes)

  assert_eq(merged.length(), 3)
  assert_eq(merged.get("a").map(fn(size) { size.width_pt }), Some(10.0))
  assert_eq(merged.get("b").map(fn(size) { size.width_pt }), Some(50.0))
  assert_eq(merged.get("v1").map(fn(size) { size.height_pt }), Some(80.0))
}
