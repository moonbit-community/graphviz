///|
test "build_cluster_local_reorder_context keeps cluster members plus local vnodes, seeds later ranks from previous-rank reachability, and excludes local fixed slots" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster_graph = root.subgraph(name="cluster_a")
  ignore(cluster_graph.node("a"))
  ignore(cluster_graph.node("b"))
  ignore(cluster_graph.node("c"))
  ignore(cluster_graph.node("d"))
  ignore(root.node("outside"))

  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["b", "outside", "a"]
  groups[1] = ["d", "\{@edge_identity.EDGE_VNODE_PREFIX}0", "c", "outside"]

  let node_order : Map[String, Int] = Map::new()
  node_order["a"] = 0
  node_order["b"] = 1
  node_order["c"] = 2
  node_order["d"] = 3
  node_order["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = 4
  node_order["outside"] = 5

  let source_out_neighbors : Map[String, Array[String]] = Map::new()
  source_out_neighbors["a"] = ["d"]
  source_out_neighbors["b"] = ["c"]

  let vnode_clusters : Map[String, String] = Map::new()
  vnode_clusters["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = "cluster_a"

  let fixed_positions : Map[String, Double] = Map::new()
  fixed_positions["a"] = 0.0
  fixed_positions["\{@edge_identity.EDGE_VNODE_PREFIX}0"] = 1.0
  fixed_positions["outside"] = 2.0

  let context = match
    build_cluster_local_reorder_context({
      cluster: "cluster_a",
      cluster_graph,
      groups,
      node_order,
      source_out_neighbors,
      vnode_clusters,
      fixed_positions,
      order_with_vnodes: true,
    }) {
    Some(value) => value
    None => fail("expected cluster local context")
  }

  assert_eq(context.cluster_node_set.get("a"), Some(true))
  assert_eq(context.cluster_node_set.get("b"), Some(true))
  assert_eq(context.cluster_node_set.get("c"), Some(true))
  assert_eq(context.cluster_node_set.get("d"), Some(true))
  assert_eq(
    context.cluster_node_set.get("\{@edge_identity.EDGE_VNODE_PREFIX}0"),
    Some(true),
  )
  assert_eq(context.cluster_node_set.get("outside"), None)
  assert_eq(context.cluster_node_order.get("a"), Some(0))
  assert_eq(context.cluster_node_order.get("b"), Some(1))
  assert_eq(context.cluster_node_order.get("c"), Some(2))
  assert_eq(context.cluster_node_order.get("d"), Some(3))
  assert_eq(
    context.cluster_node_order.get("\{@edge_identity.EDGE_VNODE_PREFIX}0"),
    Some(4),
  )
  assert_eq(context.cluster_groups.get(0), Some(["a", "b"]))
  assert_eq(
    context.cluster_groups.get(1),
    Some(["d", "\{@edge_identity.EDGE_VNODE_PREFIX}0", "c"]),
  )
  assert_eq(context.cluster_rank_keys, [0, 1])
  assert_eq(context.cluster_fixed_positions.length(), 1)
  assert_eq(context.cluster_fixed_positions.get("outside"), Some(2.0))
}

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
test "apply_cluster_rank_reorder_output rewrites only cluster member slots and leaves other ranks unchanged when desired order is trivial" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["left", "a", "middle", "b", "right"]
  groups[1] = ["keep", "c"]

  let ordered_cluster : Map[Int, Array[String]] = Map::new()
  ordered_cluster[0] = ["b", "a"]
  ordered_cluster[1] = ["c"]

  let cluster_node_set : Map[String, Bool] = Map::new()
  cluster_node_set["a"] = true
  cluster_node_set["b"] = true
  cluster_node_set["c"] = true

  apply_cluster_rank_reorder_output(
    groups,
    [0, 1],
    ordered_cluster,
    cluster_node_set,
  )

  assert_eq(groups.get(0), Some(["left", "b", "middle", "a", "right"]))
  assert_eq(groups.get(1), Some(["keep", "c"]))
}

///|
test "normalize_external_neighbor_name collapses unresolved external clusters but preserves local expanded and unclustered neighbors" {
  let expanded_clusters : Map[String, Bool] = Map::new()
  expanded_clusters["cluster_done"] = true

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["local"] = "cluster_a"
  intercluster_keys["pending"] = "cluster_pending"
  intercluster_keys["done"] = "cluster_done"

  assert_eq(
    normalize_external_neighbor_name(
      "local", "cluster_a", expanded_clusters, intercluster_keys, "%0",
    ),
    "local",
  )
  assert_eq(
    normalize_external_neighbor_name(
      "pending", "cluster_a", expanded_clusters, intercluster_keys, "%0",
    ),
    "%0",
  )
  assert_eq(
    normalize_external_neighbor_name(
      "done", "cluster_a", expanded_clusters, intercluster_keys, "%0",
    ),
    "done",
  )
  assert_eq(
    normalize_external_neighbor_name(
      "plain", "cluster_a", expanded_clusters, intercluster_keys, "%0",
    ),
    "plain",
  )
}

///|
test "has_source_external_anchor detects source neighbors outside the active cluster from either direction" {
  let cluster_node_set : Map[String, Bool] = Map::new()
  cluster_node_set["a"] = true
  cluster_node_set["b"] = true

  let source_out_neighbors : Map[String, Array[String]] = Map::new()
  source_out_neighbors["a"] = ["b"]
  source_out_neighbors["b"] = ["outside_out"]
  let source_in_neighbors : Map[String, Array[String]] = Map::new()
  source_in_neighbors["a"] = ["outside_in"]
  source_in_neighbors["b"] = ["a"]

  assert_true(
    has_source_external_anchor(
      "a", cluster_node_set, source_out_neighbors, source_in_neighbors,
    ),
  )
  assert_true(
    has_source_external_anchor(
      "b", cluster_node_set, source_out_neighbors, source_in_neighbors,
    ),
  )
  assert_false(
    has_source_external_anchor(
      "missing", cluster_node_set, source_out_neighbors, source_in_neighbors,
    ),
  )
}

///|
test "append_raw_neighbors_with_external_anchor skips synthetic names, dedupes local names, and keeps one anchor per unresolved external cluster" {
  let merge_context : LocalNeighborMergeContext = {
    cluster: "cluster_a",
    cluster_node_set: { "a": true, "b": true },
    expanded_clusters: { "cluster_done": true },
    neighbor_sources: {
      source_out_neighbors: Map::new(),
      source_in_neighbors: Map::new(),
      raw_out_neighbors: Map::new(),
      raw_in_neighbors: Map::new(),
    },
    intercluster_keys: {
      "a": "cluster_a",
      "b": "cluster_a",
      "pending_1": "cluster_pending",
      "pending_2": "cluster_pending",
      "other_pending": "cluster_other",
      "done": "cluster_done",
    },
    allow_raw_neighbors: true,
    external_anchor_name: "%0",
  }

  let neighbors = ["a"]
  append_raw_neighbors_with_external_anchor(
    neighbors,
    [
      "a",
      "pending_1",
      "pending_2",
      "other_pending",
      "done",
      "\{@edge_identity.EDGE_VNODE_PREFIX}0",
      @cluster_identity.cluster_skeleton_name("cluster_skip", 0),
    ],
    merge_context,
  )

  assert_eq(neighbors, ["a", "%0", "%0", "done"])
}

///|
test "build_local_neighbor_maps merges raw agseq neighbors only when source lists stay local" {
  let neighbor_sources : ClusterLocalNeighborSources = {
    source_out_neighbors: { "a": ["b"], "b": ["outside_from_source"] },
    source_in_neighbors: { "a": [], "b": ["a"] },
    raw_out_neighbors: {
      "a": [
        "b",
        "pending_1",
        "pending_2",
        "done",
        "\{@edge_identity.EDGE_VNODE_PREFIX}0",
      ],
      "b": ["raw_only_should_not_merge"],
    },
    raw_in_neighbors: {
      "a": ["done", "other_pending"],
      "b": ["raw_in_should_not_merge"],
    },
  }

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["a"] = "cluster_a"
  intercluster_keys["b"] = "cluster_a"
  intercluster_keys["pending_1"] = "cluster_pending"
  intercluster_keys["pending_2"] = "cluster_pending"
  intercluster_keys["other_pending"] = "cluster_other"
  intercluster_keys["done"] = "cluster_done"

  let merged = build_local_neighbor_maps(
    "cluster_a",
    { "cluster_done": true },
    ["a", "b"],
    neighbor_sources,
    intercluster_keys,
    true,
  )

  assert_eq(merged.graphviz_out_neighbors.get("a"), Some(["b", "%0", "done"]))
  assert_eq(merged.graphviz_in_neighbors.get("a"), Some(["done", "%0"]))
  assert_eq(
    merged.graphviz_out_neighbors.get("b"),
    Some(["outside_from_source"]),
  )
  assert_eq(merged.graphviz_in_neighbors.get("b"), Some(["a"]))
}
