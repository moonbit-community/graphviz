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
