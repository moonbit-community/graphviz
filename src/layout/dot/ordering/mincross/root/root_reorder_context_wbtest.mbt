///|
test "build_root_reorder_node_order prefers nlist order for materialized nodes and backfills missing names from rank-group order" {
  let root_groups : Map[Int, Array[String]] = Map::new()
  root_groups[0] = ["a", "c"]
  root_groups[1] = ["b"]

  let graph_output = @order_graph.build_order_graph_and_nodes(
    "root_node_order",
    ["a", "b", "c"],
  )

  let node_order = build_root_reorder_node_order(
    ["ghost", "a", "b"],
    graph_output.order_node_map,
    root_groups,
  )

  assert_eq(node_order.get("a"), Some(0))
  assert_eq(node_order.get("b"), Some(1))
  assert_eq(node_order.get("c"), Some(1))
}

///|
test "has_multiple_non_empty_cluster_keys ignores empties and duplicates and detects when two real clusters are present" {
  assert_false(
    has_multiple_non_empty_cluster_keys({
      "root": "",
      "member_a": "cluster_a",
      "member_a_dup": "cluster_a",
    }),
  )
  assert_true(
    has_multiple_non_empty_cluster_keys({
      "member_a": "cluster_a",
      "member_b": "cluster_b",
      "root": "",
    }),
  )
}

///|
test "should_enable_root_flip requires graphviz_flip and allows fixture mode to bypass cluster-count gating" {
  let env_key = "DOT_CAPTURE_ORDERING_FIXTURE_MODE"
  let original = @sys.get_env_var(env_key)
  let one_cluster = { "member_a": "cluster_a", "root": "" }
  let two_clusters = { "member_a": "cluster_a", "member_b": "cluster_b" }

  @sys.unset_env_var(env_key)
  let disabled = should_enable_root_flip(false, two_clusters)
  let gated_off = should_enable_root_flip(true, one_cluster)
  let gated_on = should_enable_root_flip(true, two_clusters)

  @sys.set_env_var(env_key, "1")
  let forced_on = should_enable_root_flip(true, one_cluster)

  match original {
    Some(value) => @sys.set_env_var(env_key, value)
    None => @sys.unset_env_var(env_key)
  }

  assert_false(disabled)
  assert_false(gated_off)
  assert_true(gated_on)
  assert_true(forced_on)
}

///|
test "finalize_root_rank_order_phase_output merges flip output back into seeded groups only when graphviz_flip is enabled" {
  let root_groups : Map[Int, Array[String]] = Map::new()
  root_groups[0] = ["member", "skel_a", "root", "tail"]

  let ordered_root : Map[Int, Array[String]] = Map::new()
  ordered_root[0] = ["root", "skel_a"]

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys["member"] = "cluster_a"
  order_cluster_keys["skel_a"] = "cluster_a"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton["skel_a"] = true

  let without_flip = finalize_root_rank_order_phase_output(
    [0],
    root_groups,
    ordered_root,
    order_cluster_keys,
    order_cluster_skeleton,
    false,
  )
  let with_flip = finalize_root_rank_order_phase_output(
    [0],
    root_groups,
    ordered_root,
    order_cluster_keys,
    order_cluster_skeleton,
    true,
  )

  assert_eq(without_flip.ordered_root.get(0), Some(["root", "skel_a"]))
  assert_eq(
    with_flip.ordered_root.get(0),
    Some(["member", "root", "skel_a", "tail"]),
  )
}

///|
test "build_root_tail_order_override keeps first-seen tails only" {
  let tail_override = build_root_tail_order_override({
    root_groups: Map::new(),
    root_rank_keys: [],
    root_edges_out: [],
    root_edge_tail_out: ["a", "b", "a", "c", "b"],
    root_edge_head_out: [],
    root_edge_tail_port_x: [],
    root_edge_head_port_x: [],
    root_edge_tail_port_order: [],
    root_edge_head_port_order: [],
    root_parents: Map::new(),
    root_children: Map::new(),
    root_edge_order: Map::new(),
    root_node_order: Map::new(),
  })

  assert_eq(tail_override, ["a", "b", "c"])
}

///|
test "build_root_reorder_edge_data replays root tails in nlist order and normalizes synthetic vnode defaults" {
  let vnode = "\{@edge_identity.EDGE_VNODE_PREFIX}0"
  let root_nodes = ["root", vnode, "leaf"]
  let root_groups : Map[Int, Array[String]] = Map::new()
  root_groups[0] = ["root", vnode]
  root_groups[1] = ["leaf"]

  let root_ranks : Map[String, Int] = Map::new()
  root_ranks["root"] = 0
  root_ranks[vnode] = 0
  root_ranks["leaf"] = 1

  let graph_output = @order_graph.build_order_graph_and_nodes(
    "root_edge_data", root_nodes,
  )

  let order_edges_by_tail_root : Map[
    String,
    Array[(String, String, Int, Bool, Double, Double, Double, Double)],
  ] = Map::new()
  order_edges_by_tail_root["root"] = [
    ("root", vnode, 5, true, 1.0, 2.0, 0.1, 0.2),
  ]
  order_edges_by_tail_root[vnode] = [
    (vnode, "leaf", 6, true, 0.0, 0.5, 0.0, 0.0),
  ]

  let edge_data = build_root_reorder_edge_data(
    {
      root_groups,
      root_rank_keys: [0, 1],
      root_ranks,
      root_nodes,
      root_graph: graph_output.order_graph,
      root_node_map: graph_output.order_node_map,
      root_nlist_order: ["root", vnode, "missing"],
      root_node_order: Map::new(),
    },
    order_edges_by_tail_root,
  )

  assert_eq(edge_data.root_edges_out.length(), 2)
  assert_eq(edge_data.root_edge_tail_out, ["root", vnode])
  assert_eq(edge_data.root_edge_head_out, [vnode, "leaf"])
  assert_eq(edge_data.root_edge_tail_port_x, [1.0, 0.0])
  assert_eq(edge_data.root_edge_head_port_x, [2.0, 0.0])
  assert_eq(edge_data.root_edge_tail_port_order, [0.1, 0.0])
  assert_eq(edge_data.root_edge_head_port_order, [0.2, 0.0])
  assert_eq(edge_data.root_children.get("root"), Some([]))
  assert_eq(edge_data.root_children.get(vnode), Some(["leaf"]))
  assert_eq(edge_data.root_children.get("leaf"), Some([]))
  assert_eq(edge_data.root_parents.get("root"), Some([]))
  assert_eq(edge_data.root_parents.get(vnode), Some([]))
  assert_eq(edge_data.root_parents.get("leaf"), Some([vnode]))
}

///|
test "build_root_reorder_context assembles filtered root groups ranks nodes nlist and fallback node order together" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let root_a = graph.node("root_a")
  let cluster_member = graph.node("cluster_member")
  let cluster_peer = graph.node("cluster_peer")
  let edge_cross = graph.edge(root_a, cluster_member)
  let edge_local = graph.edge(cluster_member, cluster_peer)

  let skeleton_0 = @cluster_identity.cluster_skeleton_name("cluster_x", 0)

  let order_groups_for_mincross : Map[Int, Array[String]] = Map::new()
  order_groups_for_mincross[0] = ["root_a", skeleton_0, "cluster_member"]
  order_groups_for_mincross[1] = ["cluster_peer", "root_b"]

  let order_cluster_keys : Map[String, String] = Map::new()
  order_cluster_keys[skeleton_0] = "cluster_x"
  order_cluster_keys["cluster_member"] = "cluster_x"
  order_cluster_keys["cluster_peer"] = "cluster_x"

  let order_cluster_skeleton : Map[String, Bool] = Map::new()
  order_cluster_skeleton[skeleton_0] = true

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["cluster_member"] = "cluster_x"
  cluster_keys["cluster_peer"] = "cluster_x"

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge_cross)] = ["v_cross"]
  edge_vnodes[@edge_identity.edge_vnode_key(edge_local)] = ["v_local"]

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[0] = ["v_cross", "v_local"]

  let vnode_order_keys_for_ordering : Map[String, Double] = Map::new()
  vnode_order_keys_for_ordering["v_cross"] = 0.5
  vnode_order_keys_for_ordering["v_local"] = 0.25

  let ranks : Map[String, Int] = Map::new()
  ranks["cluster_member"] = 0
  ranks["cluster_peer"] = 1

  let context = build_root_reorder_context({
    order_with_vnodes: true,
    order_rank_keys: [0, 1],
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    edges: [edge_cross, edge_local],
    edge_tail: [],
    edge_head: [],
    cluster_keys,
    edge_vnodes,
    vnodes_by_rank,
    vnode_order_keys_for_ordering,
    nlist_order: ["cluster_member", "root_b", "root_a"],
    ranks,
    skeleton_edge_creation: [(skeleton_0, "root_b")],
    root_edge_creation: [("root_b", "root_a")],
    flat_rank_constraints: Map::new(),
  })

  assert_eq(context.root_groups.get(0), Some(["root_a", "v_cross", skeleton_0]))
  assert_eq(context.root_groups.get(1), Some(["root_b"]))
  assert_eq(context.root_rank_keys, [0, 1])
  assert_eq(context.root_ranks.get("root_a"), Some(0))
  assert_eq(context.root_ranks.get("v_cross"), Some(0))
  assert_eq(context.root_ranks.get(skeleton_0), Some(0))
  assert_eq(context.root_ranks.get("root_b"), Some(1))
  assert_eq(context.root_nodes, ["root_a", "v_cross", skeleton_0, "root_b"])
  assert_true(context.root_node_map.get("v_cross") is Some(_))
  assert_eq(context.root_nlist_order, [
    skeleton_0, "root_b", "root_a", "v_cross",
  ])
  assert_eq(context.root_node_order.get(skeleton_0), Some(0))
  assert_eq(context.root_node_order.get("root_b"), Some(1))
  assert_eq(context.root_node_order.get("root_a"), Some(2))
  assert_eq(context.root_node_order.get("v_cross"), Some(3))
}
