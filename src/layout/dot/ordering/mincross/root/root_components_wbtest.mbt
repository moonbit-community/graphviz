///|
test "build_component_traversal_starts sorts by root order and prefers real nodes over edge vnodes" {
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"

  let starts = build_component_traversal_starts([vnode, "b", "a"], {
    "a": 2,
    "b": 1,
  })

  assert_eq(starts.start_nodes, [vnode, "b", "a"])
  assert_eq(starts.traversal_starts, ["b", "a"])
}

///|
test "build_flat_constraint_adjacency keeps only enabled parseable links inside the active node set" {
  let node_set = build_node_membership_set(["a", "b"])
  let adjacency = build_flat_constraint_adjacency(["a", "b", "c"], node_set, {
    "a|b": true,
    "b|c": true,
    "a|": true,
    "no_delimiter": true,
    "b|a": false,
  })

  assert_eq(adjacency.flat_out.get("a"), Some(["b"]))
  assert_eq(adjacency.flat_out.get("b"), Some([]))
  assert_eq(adjacency.flat_out.get("c"), Some([]))
  assert_eq(adjacency.flat_in.get("a"), Some([]))
  assert_eq(adjacency.flat_in.get("b"), Some(["a"]))
  assert_eq(adjacency.flat_in.get("c"), Some([]))
}

///|
test "collect_components_from_traversal replays preferred starts first and then remaining starts" {
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"
  let order_nodes = [vnode, "a", "b", "c", "d"]
  let node_set = build_node_membership_set(order_nodes)
  let out_neighbors : Map[String, Array[String]] = Map::new()
  out_neighbors[vnode] = []
  out_neighbors["a"] = [vnode]
  out_neighbors["b"] = []
  out_neighbors["c"] = ["d"]
  out_neighbors["d"] = []

  let in_neighbors : Map[String, Array[String]] = Map::new()
  in_neighbors[vnode] = ["a"]
  in_neighbors["a"] = []
  in_neighbors["b"] = []
  in_neighbors["c"] = []
  in_neighbors["d"] = ["c"]

  let flat_out : Map[String, Array[String]] = Map::new()
  flat_out[vnode] = []
  flat_out["a"] = []
  flat_out["b"] = []
  flat_out["c"] = []
  flat_out["d"] = []

  let flat_in : Map[String, Array[String]] = Map::new()
  flat_in[vnode] = []
  flat_in["a"] = []
  flat_in["b"] = []
  flat_in["c"] = []
  flat_in["d"] = []

  let adjacency : ComponentTraversalAdjacency = {
    out_neighbors,
    in_neighbors,
    flat_out,
    flat_in,
  }
  let starts : ComponentTraversalStarts = {
    start_nodes: order_nodes,
    traversal_starts: ["a", "c"],
  }

  let components = collect_components_from_traversal(
    order_nodes, node_set, starts, adjacency,
  )

  assert_eq(components, [["a", vnode], ["c", "d"], ["b"]])
}

///|
test "collect_noncluster_components builds components from rank groups and flat constraints in root order" {
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", vnode]
  groups[1] = ["b", "c"]
  let order_index : Map[String, Int] = Map::new()
  order_index["a"] = 0
  order_index[vnode] = 1
  order_index["b"] = 2
  order_index["c"] = 3
  let out_neighbors : Map[String, Array[String]] = Map::new()
  out_neighbors["a"] = []
  out_neighbors[vnode] = []
  out_neighbors["b"] = []
  out_neighbors["c"] = []
  let in_neighbors : Map[String, Array[String]] = Map::new()
  in_neighbors["a"] = []
  in_neighbors[vnode] = []
  in_neighbors["b"] = []
  in_neighbors["c"] = []

  let components = collect_noncluster_components(
    [0, 1],
    groups,
    order_index,
    out_neighbors,
    in_neighbors,
    { "a|b": true },
  )

  assert_eq(components, [["a", "b"], ["c"], [vnode]])
}

///|
test "filter_component_rank_groups preserves per-rank order and drops empty ranks" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[1] = ["c"]
  groups[2] = ["d", "e"]

  let filtered = filter_component_rank_groups(
    [0, 1, 2],
    groups,
    build_node_membership_set(["b", "d"]),
  )

  assert_eq(filtered.get(0), Some(["b"]))
  assert_eq(filtered.get(1), None)
  assert_eq(filtered.get(2), Some(["d"]))
}

///|
test "append_component_rank_groups appends each component rank output into the merged map in rank order" {
  let merged : Map[Int, Array[String]] = Map::new()
  merged[0] = ["existing0"]
  merged[1] = []
  merged[2] = ["existing2"]

  let ordered_component : Map[Int, Array[String]] = Map::new()
  ordered_component[0] = ["a0", "a1"]
  ordered_component[2] = ["c0"]

  append_component_rank_groups([0, 1, 2], merged, ordered_component)

  assert_eq(merged.get(0), Some(["existing0", "a0", "a1"]))
  assert_eq(merged.get(1), Some([]))
  assert_eq(merged.get(2), Some(["existing2", "c0"]))
}

///|
test "build_root_component_runtime_plan disables component traversal and flip when cluster keys are present" {
  let (clustered_components, clustered_flip) = build_root_component_runtime_plan(
    { "a": "cluster_a" },
    true,
    [0],
    { 0: ["a"] },
    { "a": 0 },
    { "a": [] },
    { "a": [] },
    Map::new(),
  )
  let (noncluster_components, noncluster_flip) = build_root_component_runtime_plan(
    Map::new(),
    true,
    [0, 1],
    { 0: ["a"], 1: ["b"] },
    { "a": 0, "b": 1 },
    { "a": [], "b": [] },
    { "a": [], "b": [] },
    Map::new(),
  )

  assert_eq(clustered_components, [])
  assert_eq(clustered_flip, false)
  assert_eq(noncluster_components, [["a"], ["b"]])
  assert_eq(noncluster_flip, true)
}
