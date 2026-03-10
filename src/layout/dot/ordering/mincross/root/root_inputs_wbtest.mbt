///|
test "normalize_synthetic_ports zeros only Graphviz synthetic default ports" {
  let skel_left = @cluster_identity.cluster_skeleton_name("cluster_left", 0)
  let skel_right = @cluster_identity.cluster_skeleton_name("cluster_right", 1)
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"

  let (skel_tail_x, skel_head_x, skel_tail_order, skel_head_order) = normalize_synthetic_ports(
    skel_left, skel_right, 0.5, 0.0, 9.0, 4.0,
  )
  assert_eq(skel_tail_x, 0.0)
  assert_eq(skel_head_x, 0.0)
  assert_eq(skel_tail_order, 0.0)
  assert_eq(skel_head_order, 0.0)

  let (
    vnode_default_tail_x,
    vnode_default_head_x,
    vnode_default_tail_order,
    vnode_default_head_order,
  ) = normalize_synthetic_ports(vnode, "leaf", 0.0, 0.5, 0.0, 0.0)
  assert_eq(vnode_default_tail_x, 0.0)
  assert_eq(vnode_default_head_x, 0.0)
  assert_eq(vnode_default_tail_order, 0.0)
  assert_eq(vnode_default_head_order, 0.0)

  let (
    vnode_custom_tail_x,
    vnode_custom_head_x,
    vnode_custom_tail_order,
    vnode_custom_head_order,
  ) = normalize_synthetic_ports(vnode, "leaf", 0.25, 0.0, 0.0, 0.0)
  assert_eq(vnode_custom_tail_x, 0.25)
  assert_eq(vnode_custom_head_x, 0.0)
  assert_eq(vnode_custom_tail_order, 0.0)
  assert_eq(vnode_custom_head_order, 0.0)

  let (real_tail_x, real_head_x, real_tail_order, real_head_order) = normalize_synthetic_ports(
    "root", "leaf", 0.0, 0.5, 0.0, 0.0,
  )
  assert_eq(real_tail_x, 0.0)
  assert_eq(real_head_x, 0.5)
  assert_eq(real_tail_order, 0.0)
  assert_eq(real_head_order, 0.0)
}

///|
test "build_root_vnode_preferred_positions keeps only edge vnodes and disables forwarding when vnode ordering is off" {
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"
  let skel = @cluster_identity.cluster_skeleton_name("cluster_a", 0)
  let preferred_positions : Map[String, Double] = Map::new()
  preferred_positions["root"] = 1.0
  preferred_positions[vnode] = 2.0
  preferred_positions[skel] = 3.0

  let enabled = build_root_vnode_preferred_positions(true, preferred_positions)
  let disabled = build_root_vnode_preferred_positions(
    false, preferred_positions,
  )

  assert_eq(enabled.length(), 1)
  assert_eq(enabled.get(vnode), Some(2.0))
  assert_eq(disabled.length(), 0)
}

///|
test "filter_root_mincross_seeded_groups_for_clusters keeps only root and skeleton names per rank" {
  let skel_a = @cluster_identity.cluster_skeleton_name("cluster_a", 0)
  let skel_b = @cluster_identity.cluster_skeleton_name("cluster_b", 1)

  let seeded_groups : Map[Int, Array[String]] = Map::new()
  seeded_groups[0] = ["root_a", "member_a", skel_a]
  seeded_groups[1] = ["member_b"]
  seeded_groups[2] = [skel_b, "root_b", "member_c"]

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys["member_a"] = "cluster_a"
  order_cluster_keys["member_b"] = "cluster_b"
  order_cluster_keys["member_c"] = "cluster_c"
  order_cluster_keys[skel_a] = "cluster_a"
  order_cluster_keys[skel_b] = "cluster_b"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skel_a] = true
  order_cluster_skeleton[skel_b] = true

  let filtered = filter_root_mincross_seeded_groups_for_clusters(
    seeded_groups, order_cluster_keys, order_cluster_skeleton,
  )

  assert_eq(filtered.get(0), Some(["root_a", skel_a]))
  assert_eq(filtered.get(1), None)
  assert_eq(filtered.get(2), Some([skel_b, "root_b"]))
}

///|
test "collect_mincross_order_edges keeps only filtered endpoints and normalizes synthetic vnode defaults" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let root = graph.node("root")
  let leaf = graph.node("leaf")
  let cluster_member = graph.node("cluster_member")
  let vnode_name = "\{@edge_identity.EDGE_VNODE_PREFIX}0"
  let vnode = graph.node(vnode_name)

  let edge_root_leaf = graph.edge(root, leaf)
  let edge_cluster_leaf = graph.edge(cluster_member, leaf)
  let edge_vnode_leaf = graph.edge(vnode, leaf)

  let mincross_nodes = build_node_membership_set(["root", vnode_name, "leaf"])

  let filtered = collect_mincross_order_edges(
    mincross_nodes,
    [edge_root_leaf, edge_cluster_leaf, edge_vnode_leaf],
    ["root", "cluster_member", vnode_name],
    ["leaf", "leaf", "leaf"],
    [1.5, 8.0, 0.0],
    [2.5, 9.0, 0.5],
    [0.1, 0.2, 0.0],
    [0.4, 0.5, 0.0],
  )

  assert_eq(filtered.order_edges_out_mincross.length(), 2)
  assert_eq(filtered.order_edge_tail_out_mincross, ["root", vnode_name])
  assert_eq(filtered.order_edge_head_out_mincross, ["leaf", "leaf"])
  assert_eq(filtered.order_edge_tail_port_x_mincross, [1.5, 0.0])
  assert_eq(filtered.order_edge_head_port_x_mincross, [2.5, 0.0])
  assert_eq(filtered.order_edge_tail_port_order_mincross, [0.1, 0.0])
  assert_eq(filtered.order_edge_head_port_order_mincross, [0.4, 0.0])
}

///|
test "resolve_root_mincross_input_groups filters cluster-internal nodes when enabled and clones override groups when provided" {
  let skel_a = @cluster_identity.cluster_skeleton_name("cluster_a", 0)

  let seeded_groups : Map[Int, Array[String]] = Map::new()
  seeded_groups[0] = ["root", "member", skel_a]

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys["member"] = "cluster_a"
  order_cluster_keys[skel_a] = "cluster_a"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skel_a] = true

  let filtered = resolve_root_mincross_input_groups(
    true,
    seeded_groups,
    order_cluster_keys,
    order_cluster_skeleton,
    None,
  )

  let override_groups : Map[Int, Array[String]] = Map::new()
  override_groups[0] = ["override_only"]
  let overridden = resolve_root_mincross_input_groups(
    true,
    seeded_groups,
    order_cluster_keys,
    order_cluster_skeleton,
    Some(override_groups),
  )

  match override_groups.get(0) {
    Some(list) => list.push("mutated")
    None => fail("missing override rank")
  }

  assert_eq(filtered.get(0), Some(["root", skel_a]))
  assert_eq(overridden.get(0), Some(["override_only"]))
}

///|
test "finalize_root_mincross_ordered_groups returns raw root ordering without clusters and merges back into seeded groups with clusters" {
  let skel_a = @cluster_identity.cluster_skeleton_name("cluster_a", 0)

  let seeded_groups : Map[Int, Array[String]] = Map::new()
  seeded_groups[0] = ["member", skel_a, "root", "tail"]

  let ordered_mincross : Map[Int, Array[String]] = Map::new()
  ordered_mincross[0] = ["root", skel_a]

  let mincross_nodes = build_node_membership_set(["root", skel_a])

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys["member"] = "cluster_a"
  order_cluster_keys[skel_a] = "cluster_a"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skel_a] = true

  let nonclustered = finalize_root_mincross_ordered_groups(
    false,
    [0],
    seeded_groups,
    ordered_mincross,
    mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
  )
  let clustered = finalize_root_mincross_ordered_groups(
    true,
    [0],
    seeded_groups,
    ordered_mincross,
    mincross_nodes,
    order_cluster_keys,
    order_cluster_skeleton,
  )

  assert_eq(nonclustered.get(0), Some(["root", skel_a]))
  assert_eq(clustered.get(0), Some(["member", "root", skel_a, "tail"]))
}

///|
test "build_root_rank_reorder_call_data filters root mincross edges, normalizes synthetic ports, and forwards only vnode preferred positions" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let root = graph.node("root")
  let leaf = graph.node("leaf")
  let cluster_member = graph.node("cluster_member")
  let skel_name = @cluster_identity.cluster_skeleton_name("cluster_a", 0)
  let skel = graph.node(skel_name)
  let vnode_name = "\{@edge_identity.EDGE_VNODE_PREFIX}0"
  let vnode = graph.node(vnode_name)

  let edge_root_leaf = graph.edge(root, leaf)
  let edge_cluster_leaf = graph.edge(cluster_member, leaf)
  let edge_skel_vnode = graph.edge(skel, vnode)
  let edge_vnode_leaf = graph.edge(vnode, leaf)

  let order_groups_for_mincross : Map[Int, Array[String]] = Map::new()
  order_groups_for_mincross[0] = ["root", skel_name]
  order_groups_for_mincross[1] = [vnode_name]
  order_groups_for_mincross[2] = ["leaf"]

  let order_ranks : Map[String, Int] = Map::new()
  order_ranks["root"] = 0
  order_ranks[skel_name] = 0
  order_ranks[vnode_name] = 1
  order_ranks["leaf"] = 2
  order_ranks["cluster_member"] = 1

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys[skel_name] = "cluster_a"
  order_cluster_keys["cluster_member"] = "cluster_a"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skel_name] = true

  let order_node_order : Map[String, Int] = Map::new()
  order_node_order["root"] = 0
  order_node_order[skel_name] = 1
  order_node_order[vnode_name] = 2
  order_node_order["leaf"] = 3

  let order_sizes_out : Map[String, @node_primitives.NodeSize] = Map::new()
  order_sizes_out["root"] = @node_primitives.node_size_from_points(10.0, 8.0)
  order_sizes_out["leaf"] = @node_primitives.node_size_from_points(12.0, 9.0)
  order_sizes_out[skel_name] = @node_primitives.node_size_from_points(6.0, 6.0)
  order_sizes_out[vnode_name] = @node_primitives.vnode_size_from_widths_with_h(
    2.0, 3.0, 5.0,
  )

  let preferred_positions_source : Map[String, Double] = Map::new()
  preferred_positions_source["root"] = 1.0
  preferred_positions_source[skel_name] = 2.0
  preferred_positions_source[vnode_name] = 3.0

  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_out_neighbors["root"] = ["leaf"]
  graphviz_out_neighbors[skel_name] = [vnode_name]
  graphviz_out_neighbors[vnode_name] = ["leaf"]
  graphviz_out_neighbors["leaf"] = []
  graphviz_out_neighbors["cluster_member"] = ["leaf"]

  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  graphviz_in_neighbors["root"] = []
  graphviz_in_neighbors[skel_name] = []
  graphviz_in_neighbors[vnode_name] = [skel_name]
  graphviz_in_neighbors["leaf"] = ["root", vnode_name, "cluster_member"]
  graphviz_in_neighbors["cluster_member"] = []

  let call_data = build_root_rank_reorder_call_data(
    order_groups_for_mincross,
    [edge_root_leaf, edge_cluster_leaf, edge_skel_vnode, edge_vnode_leaf],
    ["root", "cluster_member", skel_name, vnode_name],
    ["leaf", "leaf", vnode_name, "leaf"],
    [1.5, 8.0, 0.5, 0.25],
    [2.5, 9.0, 0.0, 0.75],
    [0.1, 0.2, 0.0, 0.3],
    [0.4, 0.5, 0.0, 0.6],
    order_ranks,
    order_cluster_keys,
    Map::new(),
    Map::new(),
    order_node_order,
    order_sizes_out,
    12.0,
    false,
    Map::new(),
    Map::new(),
    preferred_positions_source,
    true,
    order_cluster_skeleton,
    { "root|leaf": true },
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    true,
  )

  assert_eq(call_data.order_rank_keys_for_mincross, [0, 1, 2])
  assert_eq(call_data.mincross_nodes.get("root"), Some(true))
  assert_eq(call_data.mincross_nodes.get(skel_name), Some(true))
  assert_eq(call_data.mincross_nodes.get(vnode_name), Some(true))
  assert_eq(call_data.mincross_nodes.get("leaf"), Some(true))
  assert_eq(call_data.mincross_nodes.get("cluster_member"), None)
  assert_eq(call_data.order_edge_tail_out_mincross, [
    "root", skel_name, vnode_name,
  ])
  assert_eq(call_data.order_edge_head_out_mincross, ["leaf", vnode_name, "leaf"])
  assert_eq(call_data.order_edge_tail_port_x_mincross, [1.5, 0.0, 0.25])
  assert_eq(call_data.order_edge_head_port_x_mincross, [2.5, 0.0, 0.75])
  assert_eq(call_data.order_edge_tail_port_order_mincross, [0.1, 0.0, 0.3])
  assert_eq(call_data.order_edge_head_port_order_mincross, [0.4, 0.0, 0.6])
  assert_eq(call_data.root_rank_reorder_inputs.preferred_positions.length(), 1)
  assert_eq(
    call_data.root_rank_reorder_inputs.preferred_positions.get(vnode_name),
    Some(3.0),
  )
  assert_eq(
    call_data.root_rank_reorder_inputs.parents.get(vnode_name),
    Some([skel_name]),
  )
  assert_eq(
    call_data.root_rank_reorder_inputs.parents.get("leaf"),
    Some(["root", vnode_name]),
  )
  assert_eq(
    call_data.root_rank_reorder_inputs.children.get("root"),
    Some(["leaf"]),
  )
  assert_eq(
    call_data.root_rank_reorder_inputs.children.get(skel_name),
    Some([vnode_name]),
  )
}
