///|
fn sample_root_reorder_inputs() -> RootRankReorderInputs {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let edge_ab = graph.edge(a, b)
  let edge_bc = graph.edge(b, c)

  {
    order_rank_keys_for_mincross: [0, 1],
    order_groups_for_mincross: { 0: ["a"], 1: ["b", "c"] },
    order_edges_out_mincross: [edge_ab, edge_bc],
    order_edge_tail_out_mincross: ["a", "b"],
    order_edge_head_out_mincross: ["b", "c"],
    order_edge_tail_port_x_mincross: [1.0, 2.0],
    order_edge_head_port_x_mincross: [3.0, 4.0],
    order_edge_tail_port_order_mincross: [0.1, 0.2],
    order_edge_head_port_order_mincross: [0.3, 0.4],
    parents: { "a": [], "b": ["a"], "c": ["b"] },
    children: { "a": ["b"], "b": ["c"], "c": [] },
    order_cluster_keys: { "a": "", "b": "", "c": "cluster_c" },
    rank_same_groups: Map::new(),
    rank_same_order: Map::new(),
    edge_order: { "a": 0, "b": 1, "c": 2 },
    order_node_order: { "a": 0, "b": 1, "c": 2 },
    order_sizes_out: { "a": @node_primitives.node_size_from_points(10.0, 8.0) },
    nodesep_pt: 12.0,
    has_edge_labels: false,
    port_order_positions: { "a": 1.0, "c": 3.0 },
    port_order_contrib: { "a": [("b", 1.0), ("c", 2.0)], "c": [("a", 3.0)] },
    preferred_positions: { "b": 2.0, "c": 4.0 },
    order_cluster_skeleton: Map::new(),
    order_flat_constraints: { "a|b": true, "b|c": true, "a|": true },
    graphviz_out_neighbors: { "a": ["b"], "b": ["c"], "c": [] },
    graphviz_in_neighbors: { "a": [], "b": ["a"], "c": ["b"] },
    graphviz_flip: true,
  }
}

///|
test "resolve_root_component_order_index prefers explicit order then fallback then zero" {
  let order_node_order : Map[String, Int] = Map::new()
  order_node_order["a"] = 4
  let fallback_order : Map[String, Int] = Map::new()
  fallback_order["b"] = 9

  assert_eq(
    resolve_root_component_order_index("a", order_node_order, fallback_order),
    4,
  )
  assert_eq(
    resolve_root_component_order_index("b", order_node_order, fallback_order),
    9,
  )
  assert_eq(
    resolve_root_component_order_index(
      "missing", order_node_order, fallback_order,
    ),
    0,
  )
}

///|
test "build_component_traversal_adjacency combines filtered graphviz neighbors with in-component flat constraints" {
  let order_nodes = ["a", "b", "c"]
  let node_set = build_node_membership_set(["a", "b"])
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_out_neighbors["a"] = ["b", "c"]
  graphviz_out_neighbors["b"] = ["c"]
  graphviz_out_neighbors["c"] = ["a"]
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_in_neighbors["a"] = ["c"]
  graphviz_in_neighbors["b"] = ["a", "c"]
  graphviz_in_neighbors["c"] = ["a", "b"]

  let adjacency = build_component_traversal_adjacency(
    order_nodes,
    node_set,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    { "b|a": true, "b|c": true, "bad_key": true },
  )

  assert_eq(adjacency.out_neighbors.get("a"), Some(["b"]))
  assert_eq(adjacency.out_neighbors.get("b"), Some([]))
  assert_eq(adjacency.out_neighbors.get("c"), Some(["a"]))
  assert_eq(adjacency.in_neighbors.get("a"), Some([]))
  assert_eq(adjacency.in_neighbors.get("b"), Some(["a"]))
  assert_eq(adjacency.in_neighbors.get("c"), Some(["a", "b"]))
  assert_eq(adjacency.flat_out.get("b"), Some(["a"]))
  assert_eq(adjacency.flat_in.get("a"), Some(["b"]))
  assert_eq(adjacency.flat_out.get("a"), Some([]))
}

///|
test "filter_component_port_order_contrib keeps only in-component sources and targets while preserving empty kept buckets" {
  let component_set = build_node_membership_set(["a", "b"])
  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  port_order_contrib["a"] = [("b", 1.0), ("c", 2.0)]
  port_order_contrib["b"] = [("c", 3.0)]
  port_order_contrib["c"] = [("a", 4.0)]

  let filtered = filter_component_port_order_contrib(
    component_set, port_order_contrib,
  )

  assert_eq(filtered.get("a"), Some([("b", 1.0)]))
  assert_eq(filtered.get("b"), Some([]))
  assert_eq(filtered.get("c"), None)
}

///|
test "filter_component_flat_constraints keeps only enabled parseable constraints fully inside the component" {
  let component_set = build_node_membership_set(["a", "b"])
  let filtered = filter_component_flat_constraints(component_set, {
    "a|b": true,
    "b|c": true,
    "a|": true,
    "bad_key": true,
    "b|a": false,
  })

  assert_eq(filtered, { "a|b": true })
}

///|
test "build_root_component_projection filters groups edges neighbors positions contribs and flat constraints to one component" {
  let component_nodes = ["a", "b"]
  let component_set = build_node_membership_set(component_nodes)
  let inputs = sample_root_reorder_inputs()

  let projection = build_root_component_projection(
    component_nodes,
    component_set,
    inputs.order_rank_keys_for_mincross,
    inputs.order_groups_for_mincross,
    inputs.order_edges_out_mincross,
    inputs.order_edge_tail_out_mincross,
    inputs.order_edge_head_out_mincross,
    inputs.order_edge_tail_port_x_mincross,
    inputs.order_edge_head_port_x_mincross,
    inputs.order_edge_tail_port_order_mincross,
    inputs.order_edge_head_port_order_mincross,
    inputs.parents,
    inputs.children,
    inputs.graphviz_out_neighbors,
    inputs.graphviz_in_neighbors,
    inputs.port_order_positions,
    inputs.preferred_positions,
    inputs.port_order_contrib,
    inputs.order_flat_constraints,
  )

  assert_eq(projection.order_groups_for_mincross.get(0), Some(["a"]))
  assert_eq(projection.order_groups_for_mincross.get(1), Some(["b"]))
  assert_eq(projection.order_edge_tail_out_mincross, ["a"])
  assert_eq(projection.order_edge_head_out_mincross, ["b"])
  assert_eq(projection.order_edge_tail_port_x_mincross, [1.0])
  assert_eq(projection.order_edge_head_port_order_mincross, [0.3])
  assert_eq(projection.parents.get("a"), Some([]))
  assert_eq(projection.parents.get("b"), Some(["a"]))
  assert_eq(projection.parents.get("c"), None)
  assert_eq(projection.children.get("a"), Some(["b"]))
  assert_eq(projection.graphviz_out_neighbors.get("a"), Some(["b"]))
  assert_eq(projection.graphviz_in_neighbors.get("b"), Some(["a"]))
  assert_eq(projection.port_order_positions, { "a": 1.0 })
  assert_eq(projection.preferred_positions, { "b": 2.0 })
  assert_eq(projection.port_order_contrib.get("a"), Some([("b", 1.0)]))
  assert_eq(projection.port_order_contrib.get("c"), None)
  assert_eq(projection.order_flat_constraints, { "a|b": true })
}

///|
test "build_root_component_reorder_inputs keeps global metadata while swapping in projection-scoped fields" {
  let component_nodes = ["a", "b"]
  let component_set = build_node_membership_set(component_nodes)
  let inputs = sample_root_reorder_inputs()

  let projected_inputs = build_root_component_reorder_inputs(
    component_nodes, component_set, inputs,
  )

  assert_eq(projected_inputs.order_groups_for_mincross.get(0), Some(["a"]))
  assert_eq(projected_inputs.order_groups_for_mincross.get(1), Some(["b"]))
  assert_eq(projected_inputs.order_edge_tail_out_mincross, ["a"])
  assert_eq(projected_inputs.order_edge_head_out_mincross, ["b"])
  assert_eq(projected_inputs.port_order_positions, { "a": 1.0 })
  assert_eq(projected_inputs.preferred_positions, { "b": 2.0 })
  assert_eq(projected_inputs.order_flat_constraints, { "a|b": true })
  assert_eq(projected_inputs.order_cluster_keys.get("c"), Some("cluster_c"))
  assert_eq(projected_inputs.nodesep_pt, 12.0)
  assert_eq(projected_inputs.graphviz_flip, true)
}
