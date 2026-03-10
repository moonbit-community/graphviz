///|
test "vnode_is_merged stays false for duplicate parallel neighbors but true for distinct neighbors" {
  let duplicate_graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  let duplicate_a = duplicate_graph.node("a")
  let duplicate_b = duplicate_graph.node("b")
  let duplicate_1 = duplicate_graph.edge(duplicate_a, duplicate_b)
  let duplicate_2 = duplicate_graph.edge(duplicate_a, duplicate_b)
  let duplicate_vnodes : Map[String, Array[String]] = Map::new()
  duplicate_vnodes[@edge_identity.edge_vnode_key(duplicate_1)] = ["v"]
  duplicate_vnodes[@edge_identity.edge_vnode_key(duplicate_2)] = ["v"]
  let duplicate_adjacency = @routesplines.build_path_adjacency(
    [duplicate_1, duplicate_2],
    duplicate_vnodes,
    [],
    [],
  )

  let merged_graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    strict=false,
  )
  let merged_a = merged_graph.node("a")
  let merged_b = merged_graph.node("b")
  let merged_c = merged_graph.node("c")
  let merged_d = merged_graph.node("d")
  let merged_1 = merged_graph.edge(merged_a, merged_b)
  let merged_2 = merged_graph.edge(merged_c, merged_d)
  let merged_vnodes : Map[String, Array[String]] = Map::new()
  merged_vnodes[@edge_identity.edge_vnode_key(merged_1)] = ["v"]
  merged_vnodes[@edge_identity.edge_vnode_key(merged_2)] = ["v"]
  let merged_adjacency = @routesplines.build_path_adjacency(
    [merged_1, merged_2],
    merged_vnodes,
    [],
    [],
  )

  assert_false(vnode_is_merged("v", duplicate_adjacency))
  assert_true(vnode_is_merged("v", merged_adjacency))
}

///|
test "recover_slack_vnodes centers normal vnodes and right-aligns the label rank" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = {
    "v1": @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0),
    "v2": @node_primitives.vnode_size_from_widths_with_h(1.0, 1.0, 4.0),
  }
  let vnode_positions : Map[String, @geom.Point] = Map::new()
  let empty_edge_vnodes : Map[String, Array[String]] = Map::new()
  let adjacency = @routesplines.build_path_adjacency(
    [],
    empty_edge_vnodes,
    [],
    [],
  )

  recover_slack_vnodes(
    {
      edge,
      ordered_vnodes: ["v1", "v2"],
      boxes: [
        { llx: 0.0, lly: 4.0, urx: 10.0, ury: 6.0 },
        { llx: 2.0, lly: 0.0, urx: 8.0, ury: 2.0 },
      ],
      ranks: { "a": 0, "b": 3 },
      vnode_ranks: { "v1": 1, "v2": 2 },
      rank_y: { 1: 5.0, 2: 1.0 },
      vnode_positions,
      vnode_sizes,
      adjacency,
    },
    (_edge, _ranks) => Some(2),
  )

  assert_eq(vnode_positions.get("v1"), Some(@edge_spline.point(5.0, 5.0)))
  assert_eq(vnode_positions.get("v2"), Some(@edge_spline.point(8.0, 1.0)))
  assert_eq(vnode_sizes.get("v1").map(fn(size) { size.left_pt }), Some(5.0))
  assert_eq(vnode_sizes.get("v1").map(fn(size) { size.right_pt }), Some(5.0))
  assert_eq(vnode_sizes.get("v2").map(fn(size) { size.left_pt }), Some(6.0))
  assert_eq(vnode_sizes.get("v2").map(fn(size) { size.right_pt }), Some(1.0))
}
