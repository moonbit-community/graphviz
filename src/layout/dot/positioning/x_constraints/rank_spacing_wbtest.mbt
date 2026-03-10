///|
fn build_rank_spacing_test_sizes() -> Map[String, @node_primitives.NodeSize] {
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = @node_primitives.vnode_size_from_widths_with_h(3.0, 4.0, 10.0)
  sizes["b"] = @node_primitives.vnode_size_from_widths_with_h(6.0, 7.0, 12.0)
  sizes["c"] = @node_primitives.vnode_size_from_widths_with_h(5.0, 8.0, 8.0)
  sizes["d"] = @node_primitives.vnode_size_from_widths_with_h(2.0, 3.0, 9.0)
  sizes["e"] = @node_primitives.vnode_size_from_widths_with_h(4.0, 5.0, 11.0)
  sizes
}

///|
test "compress_width_minlen_pt respects ratio rankdir swap and clamp" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("size", "2,3!")

  assert_eq(compress_width_minlen_pt(graph, @rankdir.RankDir::TB), None)

  graph.set_attr("ratio", " compress ")
  assert_eq(compress_width_minlen_pt(graph, @rankdir.RankDir::TB), Some(144))
  assert_eq(compress_width_minlen_pt(graph, @rankdir.RankDir::LR), Some(216))

  graph.set_attr("size", "1000000,1000000")
  assert_eq(compress_width_minlen_pt(graph, @rankdir.RankDir::TB), Some(65535))
}

///|
test "compute_rank_positions applies edge-label spacing only on odd ranks" {
  let sizes = build_rank_spacing_test_sizes()
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["d", "e"]
  groups[1] = ["a", "b", "c"]

  let positions = compute_rank_positions([0, 1], groups, sizes, 12.0, true)

  assert_eq(positions.get("d"), Some(0.0))
  assert_eq(positions.get("e"), Some(19.0))
  assert_eq(positions.get("a"), Some(0.0))
  assert_eq(positions.get("b"), Some(15.0))
  assert_eq(positions.get("c"), Some(32.0))
}
