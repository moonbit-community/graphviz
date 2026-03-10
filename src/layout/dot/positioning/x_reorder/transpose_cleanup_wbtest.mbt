///|
test "apply_xpos_transpose_cleanup removes a simple crossing in place" {
  let (graph, node_map) = new_test_graph(["a", "b", "x", "y"])
  let ax = graph.edge(node_map["a"], node_map["x"])
  let by = graph.edge(node_map["b"], node_map["y"])

  let x_groups : Map[Int, Array[String]] = Map::new()
  x_groups[0] = ["a", "b"]
  x_groups[1] = ["y", "x"]

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["x"] = 1
  ranks["y"] = 1

  let edge_in : Map[String, Array[Int]] = Map::new()
  edge_in["x"] = [0]
  edge_in["y"] = [1]
  let edge_out : Map[String, Array[Int]] = Map::new()
  let before_crossings = @reorder.count_rank_crossings_port(
    1,
    x_groups.get(1).unwrap_or([]),
    ranks,
    @rank_groups.build_order_index(x_groups),
    edge_in,
    edge_out,
    ["a", "b"],
    ["x", "y"],
    [0.0, 0.0],
    [0.0, 0.0],
    [1, 1],
  )

  apply_xpos_transpose_cleanup(
    x_groups,
    {
      nodes: [node_map["a"], node_map["b"], node_map["x"], node_map["y"]],
      order_edges: [ax, by],
      order_edge_tail: ["a", "b"],
      order_edge_head: ["x", "y"],
      ranks,
      edge_vnodes: Map::new(),
      vnode_ranks: Map::new(),
    },
    2,
  )

  let after_crossings = @reorder.count_rank_crossings_port(
    1,
    x_groups.get(1).unwrap_or([]),
    ranks,
    @rank_groups.build_order_index(x_groups),
    edge_in,
    edge_out,
    ["a", "b"],
    ["x", "y"],
    [0.0, 0.0],
    [0.0, 0.0],
    [1, 1],
  )

  assert_eq(before_crossings, 1)
  assert_eq(after_crossings, 0)
}
