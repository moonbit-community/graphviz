///|
test "box vertex normalization preserves the box dimensions" {
  let extent = box_vertex_extent(452.25, 84.0)
  assert_true((extent.width_pt - 452.25).abs() < 0.000000000001)
  assert_true(extent.height_pt == 84.0)
}
