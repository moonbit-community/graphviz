///|
test "build_materialized_graphviz_neighbors preserves per-tail head order and AGSEQ-style incoming order" {
  let order_nodes = ["a", "b", "c", "isolated"]
  let order_edges_by_tail : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
  order_edges_by_tail["a"] = [
    ("a", "c", 1, true, 0.0, 0.0, 0.0, 0.0),
    ("a", "b", 2, true, 0.0, 0.0, 0.0, 0.0),
  ]
  order_edges_by_tail["b"] = [("b", "c", 3, true, 0.0, 0.0, 0.0, 0.0)]

  let neighbors = build_materialized_graphviz_neighbors(
    order_nodes,
    order_edges_by_tail,
    [("b", "c"), ("a", "c"), ("a", "b")],
  )

  assert_eq(neighbors.out_neighbors.get("a"), Some(["c", "b"]))
  assert_eq(neighbors.out_neighbors.get("b"), Some(["c"]))
  assert_eq(neighbors.out_neighbors.get("c"), Some([]))
  assert_eq(neighbors.out_neighbors.get("isolated"), Some([]))
  assert_eq(neighbors.in_neighbors.get("a"), Some([]))
  assert_eq(neighbors.in_neighbors.get("b"), Some(["a"]))
  assert_eq(neighbors.in_neighbors.get("c"), Some(["b", "a"]))
  assert_eq(neighbors.in_neighbors.get("isolated"), Some([]))
}

///|
test "build_order_materialization_data replays mapped and unmapped tails in nlist order and copies flat constraints" {
  let order_nodes = ["a", "b", "c"]
  let mapped_graph_output = @order_graph.build_order_graph_and_nodes(
    "mapped_test", order_nodes,
  )
  let unmapped_graph_output = @order_graph.build_order_graph_and_nodes(
    "unmapped_test", order_nodes,
  )

  let order_edges_by_tail : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
  order_edges_by_tail["a"] = [
    ("a", "b", 5, true, 1.0, 2.0, 0.1, 0.2),
    ("a", "c", 6, false, 3.0, 4.0, 0.3, 0.4),
  ]
  order_edges_by_tail["b"] = [("b", "c", 7, true, 5.0, 6.0, 0.5, 0.6)]

  let order_edges_by_tail_unmapped : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
  order_edges_by_tail_unmapped["a"] = [("a", "c", 9, true, 7.0, 8.0, 0.7, 0.8)]
  order_edges_by_tail_unmapped["b"] = [
    ("b", "a", 10, false, 9.0, 10.0, 0.9, 1.0),
  ]

  let flat_constraints : Map[String, Bool] = Map::new()
  flat_constraints["a|b"] = true

  let materialized = build_order_materialization_data({
    nlist_order: ["b", "missing", "a"],
    order_edges_by_tail,
    order_graph: mapped_graph_output.order_graph,
    order_node_map: mapped_graph_output.order_node_map,
    order_edges_by_tail_unmapped,
    order_graph_unmapped: unmapped_graph_output.order_graph,
    order_node_map_unmapped: unmapped_graph_output.order_node_map,
    order_nodes,
    edge_creation_order: [("a", "c"), ("b", "c"), ("a", "b")],
    flat_constraints,
  })

  flat_constraints["b|c"] = false

  assert_eq(materialized.order_edges_out.length(), 3)
  assert_eq(materialized.order_edge_tail_out, ["b", "a", "a"])
  assert_eq(materialized.order_edge_head_out, ["c", "b", "c"])
  assert_eq(materialized.order_edge_tail_port_x, [5.0, 1.0, 3.0])
  assert_eq(materialized.order_edge_head_port_x, [6.0, 2.0, 4.0])
  assert_eq(materialized.order_edge_tail_port_order, [0.5, 0.1, 0.3])
  assert_eq(materialized.order_edge_head_port_order, [0.6, 0.2, 0.4])
  assert_eq(materialized.order_edges_out_unmapped.length(), 2)
  assert_eq(materialized.order_edge_tail_out_unmapped, ["b", "a"])
  assert_eq(materialized.order_edge_head_out_unmapped, ["a", "c"])
  assert_eq(materialized.order_edge_tail_port_x_unmapped, [9.0, 7.0])
  assert_eq(materialized.order_edge_head_port_x_unmapped, [10.0, 8.0])
  assert_eq(materialized.order_edge_tail_port_order_unmapped, [0.9, 0.7])
  assert_eq(materialized.order_edge_head_port_order_unmapped, [1.0, 0.8])
  assert_eq(materialized.graphviz_out_neighbors.get("a"), Some(["b", "c"]))
  assert_eq(materialized.graphviz_out_neighbors.get("b"), Some(["c"]))
  assert_eq(materialized.graphviz_out_neighbors.get("c"), Some([]))
  assert_eq(materialized.graphviz_in_neighbors.get("a"), Some([]))
  assert_eq(materialized.graphviz_in_neighbors.get("b"), Some(["a"]))
  assert_eq(materialized.graphviz_in_neighbors.get("c"), Some(["a", "b"]))
  assert_eq(materialized.order_flat_constraints, { "a|b": true })
}
