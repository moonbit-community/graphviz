// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_remincross_groups prefers seeded vnode-inclusive replay for single-cluster cleanup" {
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_only", 0)

  let final_groups : Map[Int, Array[String]] = Map::new()
  final_groups[0] = ["a", "b"]

  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  ordered_with_vnodes[0] = [skeleton, "v_before", "a", "b"]

  let rem_groups = build_remincross_groups({
    ratio: "",
    cluster_order: ["cluster_only"],
    ordered_with_vnodes,
    cluster_keys: Map::new(),
    vnode_group_inputs: {
      final_groups,
      order_with_vnodes: true,
      edges: [],
      edge_tail: [],
      edge_head: [],
      edge_reversed: [],
      ranks: Map::new(),
      intercluster_keys: Map::new(),
      cluster_parents: Map::new(),
      cluster_min_rank: Map::new(),
      cluster_max_rank: Map::new(),
      edge_vnodes: Map::new(),
      vnode_ranks: Map::new(),
      vnodes_by_rank: Map::new(),
    },
  })

  assert_eq(rem_groups.get(0), Some(["v_before", "a", "b"]))
}

///|
test "build_remincross_groups falls back to vnode-group rebuild when seeded replay is empty under ratio fill" {
  let skeleton = @cluster_identity.cluster_skeleton_name("cluster_only", 0)

  let final_groups : Map[Int, Array[String]] = Map::new()
  final_groups[0] = ["a"]
  final_groups[1] = ["b"]

  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  ordered_with_vnodes[0] = [skeleton]

  let rem_groups = build_remincross_groups({
    ratio: "fill",
    cluster_order: ["cluster_a", "cluster_b"],
    ordered_with_vnodes,
    cluster_keys: Map::new(),
    vnode_group_inputs: {
      final_groups,
      order_with_vnodes: true,
      edges: [],
      edge_tail: [],
      edge_head: [],
      edge_reversed: [],
      ranks: Map::new(),
      intercluster_keys: Map::new(),
      cluster_parents: Map::new(),
      cluster_min_rank: Map::new(),
      cluster_max_rank: Map::new(),
      edge_vnodes: Map::new(),
      vnode_ranks: Map::new(),
      vnodes_by_rank: Map::new(),
    },
  })

  assert_eq(rem_groups.get(0), Some(["a"]))
  assert_eq(rem_groups.get(1), Some(["b"]))
}

///|
test "build_remincross_vnode_groups injects root-boundary trailing vnodes after real nodes on their rank" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let root = graph.node("root")
  let cluster_node = graph.node("cluster_node")
  let edge = graph.edge(root, cluster_node)

  let final_groups : Map[Int, Array[String]] = Map::new()
  final_groups[0] = ["root"]
  final_groups[1] = ["mid_real"]
  final_groups[2] = ["cluster_node"]

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes[@edge_identity.edge_vnode_key(edge)] = ["v_trail"]

  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v_trail"] = 1

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[1] = ["v_trail"]

  let ranks : Map[String, Int] = Map::new()
  ranks["root"] = 0
  ranks["mid_real"] = 1
  ranks["cluster_node"] = 2

  let intercluster_keys : Map[String, String] = Map::new()
  intercluster_keys["root"] = ""
  intercluster_keys["cluster_node"] = "cluster_a"

  let rem_groups = build_remincross_vnode_groups({
    final_groups,
    order_with_vnodes: true,
    edges: [edge],
    edge_tail: [],
    edge_head: [],
    edge_reversed: [false],
    ranks,
    intercluster_keys,
    cluster_parents: Map::new(),
    cluster_min_rank: { "cluster_a": 2 },
    cluster_max_rank: { "cluster_a": 2 },
    edge_vnodes,
    vnode_ranks,
    vnodes_by_rank,
  })

  assert_eq(rem_groups.get(0), Some(["root"]))
  assert_eq(rem_groups.get(1), Some(["mid_real", "v_trail"]))
  assert_eq(rem_groups.get(2), Some(["cluster_node"]))
}
