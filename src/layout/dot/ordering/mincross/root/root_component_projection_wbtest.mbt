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
