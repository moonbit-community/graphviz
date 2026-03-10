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
