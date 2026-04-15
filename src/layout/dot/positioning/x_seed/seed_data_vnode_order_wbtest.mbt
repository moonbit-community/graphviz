// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_x_seed_data derives vnode order from edge-vnode chains when explicit vnode groups are absent" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)

  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = ["tail"]
  ordered_groups[1] = ["mid_real"]
  ordered_groups[2] = ["head"]

  let ranks : Map[String, Int] = Map::new()
  ranks["tail"] = 0
  ranks["head"] = 2

  let edge_vnodes : Map[String, Array[String]] = Map::new()
  edge_vnodes["tail|head||"] = ["v_mid"]

  let vnode_ranks : Map[String, Int] = Map::new()
  vnode_ranks["v_mid"] = 1

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[1] = ["v_mid"]

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["v_mid"] = sample_node_size(14.0, 6.0)

  let seed = build_x_seed_data(
    {
      use_vnodes_for_xpos: true,
      ordered_groups,
      ordered_groups_with_vnodes: Map::new(),
      edges: [edge],
      edge_tail: [],
      edge_head: [],
      edge_reversed: [false],
      ranks,
      intercluster_keys: { "tail": "", "head": "cluster_a" },
      cluster_parents: Map::new(),
      edge_vnodes,
      vnode_ranks,
      vnodes_by_rank,
      has_clusters: true,
      cluster_keys: { "tail": "", "head": "cluster_a" },
      vnode_clusters: Map::new(),
      vnode_sizes,
    },
    () => {
      let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
      sizes["tail"] = sample_node_size(10.0, 10.0)
      sizes["mid_real"] = sample_node_size(9.0, 9.0)
      sizes["head"] = sample_node_size(12.0, 12.0)
      sizes
    },
    _sizes => {
      x_edge_tail_port_x: [],
      x_edge_head_port_x: [],
      x_edge_tail_port_order: [],
      x_edge_head_port_order: [],
      order_edge_tail_port_x: [],
      order_edge_head_port_x: [],
      order_edge_tail_port_order: [],
      order_edge_head_port_order: [],
    },
  )

  assert_eq(seed.has_vnode_order, true)
  assert_eq(seed.x_groups.get(0), Some(["tail"]))
  assert_eq(seed.x_groups.get(1), Some(["mid_real", "v_mid"]))
  assert_eq(seed.x_groups.get(2), Some(["head"]))
  assert_eq(seed.x_order_sizes.length(), 4)
}
