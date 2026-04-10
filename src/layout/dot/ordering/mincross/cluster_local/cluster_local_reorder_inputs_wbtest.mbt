// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_local_reorder_inputs keeps crossing edges when enabled and scopes metadata to the active cluster node subset" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let ext = graph.node("ext")
  let a = graph.node("a")
  let vnode = graph.node("\{@edge_identity.EDGE_VNODE_PREFIX}0")
  let b = graph.node("b")
  let edge_ext_a = graph.edge(ext, a)
  let edge_a_v = graph.edge(a, vnode)
  let edge_v_b = graph.edge(vnode, b)
  let edge_b_ext = graph.edge(b, ext)

  let source_out_neighbors : Map[String, Array[String]] = Map::new()
  source_out_neighbors["a"] = ["\{@edge_identity.EDGE_VNODE_PREFIX}0"]
  source_out_neighbors["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = ["b"]
  source_out_neighbors["b"] = ["ext"]
  let source_in_neighbors : Map[String, Array[String]] = Map::new()
  source_in_neighbors["a"] = ["ext"]
  source_in_neighbors["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = ["a"]
  source_in_neighbors["b"] = ["\{@edge_identity.EDGE_VNODE_PREFIX}0"]

  let neighbor_sources = build_cluster_local_neighbor_sources(
    graph, source_out_neighbors, source_in_neighbors,
  )

  let cluster_node_set : Map[String, Bool] = Map::new()
  cluster_node_set["a"] = true
  cluster_node_set["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = true
  cluster_node_set["b"] = true

  let fixed_ranks : Map[String, Int] = Map::new()
  fixed_ranks["ext"] = 0
  fixed_ranks["a"] = 1
  fixed_ranks["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = 2
  fixed_ranks["b"] = 3

  let order_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  order_sizes["a"] = @node_primitives.node_size_from_points(10.0, 8.0)
  order_sizes["b"] = @node_primitives.node_size_from_points(12.0, 9.0)
  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = @node_primitives.vnode_size_from_widths_with_h(
    2.0, 3.0, 5.0,
  )

  let input_phase_output = build_local_reorder_inputs({
    cluster_name: "cluster_a",
    include_external_crossing: true,
    expanded_clusters: Map::new(),
    order_edges: [edge_ext_a, edge_a_v, edge_v_b, edge_b_ext],
    order_edge_tail: ["ext", "a", "\{@edge_identity.EDGE_VNODE_PREFIX}0", "b"],
    order_edge_head: ["a", "\{@edge_identity.EDGE_VNODE_PREFIX}0", "b", "ext"],
    order_edge_tail_port_x: [1.0, 2.0, 3.0, 4.0],
    order_edge_head_port_x: [1.5, 2.5, 3.5, 4.5],
    order_edge_tail_port_order: [0.1, 0.2, 0.3, 0.4],
    order_edge_head_port_order: [0.5, 0.6, 0.7, 0.8],
    neighbor_sources,
    cluster_node_set,
    cluster_nodes: ["a", "\{@edge_identity.EDGE_VNODE_PREFIX}0", "b"],
    fixed_ranks,
    order_sizes,
    vnode_sizes,
    intercluster_keys: { "ext": "cluster_ext" },
    flat_constraints: { "a|b": true, "a|ext": true, "bad_key": true },
  })

  assert_eq(input_phase_output.cluster_edge_tail, [
    "ext",
    "a",
    "\{@edge_identity.EDGE_VNODE_PREFIX}0",
    "b",
  ])
  assert_eq(input_phase_output.cluster_edge_head, [
    "a",
    "\{@edge_identity.EDGE_VNODE_PREFIX}0",
    "b",
    "ext",
  ])
  assert_eq(input_phase_output.cluster_edge_tail_port_x, [1.0, 2.0, 3.0, 4.0])
  assert_eq(input_phase_output.cluster_edge_head_port_order, [
    0.5, 0.6, 0.7, 0.8,
  ])
  assert_eq(input_phase_output.parents.get("a"), Some(["ext"]))
  assert_eq(
    input_phase_output.parents.get("\{@edge_identity.EDGE_VNODE_PREFIX}0"),
    Some(["a"]),
  )
  assert_eq(
    input_phase_output.parents.get("b"),
    Some(["\{@edge_identity.EDGE_VNODE_PREFIX}0"]),
  )
  assert_eq(
    input_phase_output.children.get("a"),
    Some(["\{@edge_identity.EDGE_VNODE_PREFIX}0"]),
  )
  assert_eq(
    input_phase_output.graphviz_out_neighbors.get("a"),
    Some(["\{@edge_identity.EDGE_VNODE_PREFIX}0"]),
  )
  assert_eq(input_phase_output.graphviz_in_neighbors.get("a"), Some(["ext"]))
  assert_eq(input_phase_output.cluster_keys.get("a"), Some(""))
  assert_eq(
    input_phase_output.cluster_keys.get("\{@edge_identity.EDGE_VNODE_PREFIX}0"),
    Some(""),
  )
  assert_eq(input_phase_output.cluster_keys.get("b"), Some(""))
  assert_eq(input_phase_output.cluster_flat_constraints, { "a|b": true })
  assert_eq(
    input_phase_output.cluster_sizes.get("a").map(fn(size) { size.width_pt }),
    Some(10.0),
  )
  assert_eq(
    input_phase_output.cluster_sizes
    .get("\{@edge_identity.EDGE_VNODE_PREFIX}0")
    .map(fn(size) { size.width_pt }),
    Some(5.0),
  )
  assert_eq(
    input_phase_output.cluster_sizes.get("b").map(fn(size) { size.height_pt }),
    Some(9.0),
  )
}

///|
test "should_include_external_crossing_edges keeps shallow clusters and only disables deep edge-free vnode-free clusters outside fixture mode" {
  let env_key = "DOT_CAPTURE_ORDERING_FIXTURE_MODE"
  let original = @sys.get_env_var(env_key)

  @sys.unset_env_var(env_key)
  let shallow_without_edges = should_include_external_crossing_edges(
    [0, 1],
    0,
    0,
  )
  let deep_without_edges_or_vnodes = should_include_external_crossing_edges(
    [0, 1, 2],
    0,
    0,
  )
  let deep_with_internal_edges = should_include_external_crossing_edges(
    [0, 1, 2],
    1,
    0,
  )
  let deep_with_vnodes = should_include_external_crossing_edges([0, 1, 2], 0, 1)

  @sys.set_env_var(env_key, "1")
  let fixture_mode_shallow = should_include_external_crossing_edges(
    [0, 1],
    9,
    9,
  )
  let fixture_mode_deep = should_include_external_crossing_edges(
    [0, 1, 2],
    9,
    9,
  )

  match original {
    Some(value) => @sys.set_env_var(env_key, value)
    None => @sys.unset_env_var(env_key)
  }

  assert_true(shallow_without_edges)
  assert_false(deep_without_edges_or_vnodes)
  assert_true(deep_with_internal_edges)
  assert_true(deep_with_vnodes)
  assert_true(fixture_mode_shallow)
  assert_false(fixture_mode_deep)
}

///|
test "build_local_reorder_inputs drops external crossing edges when disabled" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let ext = graph.node("ext")
  let a = graph.node("a")
  let vnode = graph.node("\{@edge_identity.EDGE_VNODE_PREFIX}0")
  let b = graph.node("b")
  let vnode_name = vnode.name()
  let edge_ext_a = graph.edge(ext, a)
  let edge_a_v = graph.edge(a, vnode)
  let edge_v_b = graph.edge(vnode, b)
  let edge_b_ext = graph.edge(b, ext)

  let source_out_neighbors : Map[String, Array[String]] = Map::new()
  source_out_neighbors["a"] = [vnode_name]
  source_out_neighbors[vnode_name] = ["b"]
  source_out_neighbors["b"] = ["ext"]

  let source_in_neighbors : Map[String, Array[String]] = Map::new()
  source_in_neighbors["a"] = ["ext"]
  source_in_neighbors[vnode_name] = ["a"]
  source_in_neighbors["b"] = [vnode_name]

  let neighbor_sources = build_cluster_local_neighbor_sources(
    graph, source_out_neighbors, source_in_neighbors,
  )

  let cluster_node_set : Map[String, Bool] = Map::new()
  cluster_node_set["a"] = true
  cluster_node_set[vnode_name] = true
  cluster_node_set["b"] = true

  let fixed_ranks : Map[String, Int] = Map::new()
  fixed_ranks["a"] = 1
  fixed_ranks[vnode_name] = 2
  fixed_ranks["b"] = 3

  let order_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  order_sizes["a"] = @node_primitives.node_size_from_points(10.0, 8.0)

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes[vnode_name] = @node_primitives.vnode_size_from_widths_with_h(
    2.0, 3.0, 5.0,
  )

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["ext"] = "cluster_ext"

  let input_phase_output = build_local_reorder_inputs({
    cluster_name: "cluster_a",
    include_external_crossing: false,
    expanded_clusters: Map::new(),
    order_edges: [edge_ext_a, edge_a_v, edge_v_b, edge_b_ext],
    order_edge_tail: ["ext", "a", vnode_name, "b"],
    order_edge_head: ["a", vnode_name, "b", "ext"],
    order_edge_tail_port_x: [1.0, 2.0, 3.0, 4.0],
    order_edge_head_port_x: [1.5, 2.5, 3.5, 4.5],
    order_edge_tail_port_order: [0.1, 0.2, 0.3, 0.4],
    order_edge_head_port_order: [0.5, 0.6, 0.7, 0.8],
    neighbor_sources,
    cluster_node_set,
    cluster_nodes: ["a", vnode_name, "b"],
    fixed_ranks,
    order_sizes,
    vnode_sizes,
    intercluster_keys,
    flat_constraints: Map::new(),
  })

  assert_eq(input_phase_output.cluster_edge_tail, ["a", vnode_name])
  assert_eq(input_phase_output.cluster_edge_head, [vnode_name, "b"])
  assert_eq(input_phase_output.cluster_edge_tail_port_x, [2.0, 3.0])
  assert_eq(input_phase_output.cluster_edge_head_port_order, [0.6, 0.7])
  assert_eq(input_phase_output.parents.get("a"), Some([]))
  assert_eq(input_phase_output.parents.get(vnode_name), Some(["a"]))
  assert_eq(input_phase_output.parents.get("b"), Some([vnode_name]))
  assert_eq(input_phase_output.children.get("a"), Some([vnode_name]))
  assert_eq(input_phase_output.children.get(vnode_name), Some(["b"]))
}
