// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn sample_node_size(
  width_pt : Double,
  height_pt : Double,
) -> @node_primitives.NodeSize {
  let half = width_pt / 2.0
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: half,
    right_pt: half,
  }
}

///|
test "build_x_seed_data uses explicit vnode groups, vnode size overlay, and vnode cluster keys" {
  let cluster_skeleton = @cluster_identity.cluster_skeleton_name("cluster_0", 0)

  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = [cluster_skeleton, "a"]

  let ordered_groups_with_vnodes : Map[Int, Array[String]] = Map::new()
  ordered_groups_with_vnodes[0] = [cluster_skeleton, "a", "v1"]

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["v1"] = 0

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster_0"
  cluster_keys[cluster_skeleton] = "cluster_0"

  let vnode_clusters : Map[String, String] = Map::new()
  vnode_clusters["v1"] = "cluster_0"

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["v1"] = sample_node_size(14.0, 6.0)

  let seed = build_x_seed_data(
    {
      use_vnodes_for_xpos: true,
      ordered_groups,
      ordered_groups_with_vnodes,
      edges: [],
      edge_tail: [],
      edge_head: [],
      edge_reversed: [],
      ranks,
      intercluster_keys: Map::new(),
      cluster_parents: Map::new(),
      edge_vnodes: Map::new(),
      vnode_ranks: Map::new(),
      vnodes_by_rank: Map::new(),
      has_clusters: true,
      cluster_keys,
      vnode_clusters,
      vnode_sizes,
    },
    () => {
      let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
      sizes["a"] = sample_node_size(10.0, 10.0)
      sizes
    },
    sizes => {
      let a_width = sizes.get("a").map(fn(s) { s.width_pt }).unwrap_or_default()
      let v1_width = sizes
        .get("v1")
        .map(fn(s) { s.width_pt })
        .unwrap_or_default()
      {
        x_edge_tail_port_x: [a_width],
        x_edge_head_port_x: [v1_width],
        x_edge_tail_port_order: [3.0],
        x_edge_head_port_order: [4.0],
        order_edge_tail_port_x: [5.0],
        order_edge_head_port_x: [6.0],
        order_edge_tail_port_order: [7.0],
        order_edge_head_port_order: [8.0],
      }
    },
  )

  assert_eq(seed.has_vnode_order, true)
  assert_eq(seed.x_groups.get(0), Some(["a", "v1"]))
  assert_eq(seed.x_cluster_keys.get("a"), Some("cluster_0"))
  assert_eq(seed.x_cluster_keys.get("v1"), Some("cluster_0"))
  assert_eq(seed.x_base_sizes.length(), 1)
  assert_eq(seed.x_order_sizes.length(), 2)
  assert_eq(seed.x_edge_tail_port_x, [10.0])
  assert_eq(seed.x_edge_head_port_x, [14.0])
  assert_eq(seed.order_edge_head_port_order, [8.0])
}

///|
test "build_x_seed_data keeps explicit cluster skeletons when cluster cleanup is disabled" {
  let cluster_skeleton = @cluster_identity.cluster_skeleton_name("cluster_0", 0)

  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = [cluster_skeleton, "a"]

  let ordered_groups_with_vnodes : Map[Int, Array[String]] = Map::new()
  ordered_groups_with_vnodes[0] = [cluster_skeleton, "a", "v1"]

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster_0"
  cluster_keys[cluster_skeleton] = "cluster_0"

  let vnode_clusters : Map[String, String] = Map::new()
  vnode_clusters["v1"] = "cluster_0"

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["v1"] = sample_node_size(14.0, 6.0)

  let seed = build_x_seed_data(
    {
      use_vnodes_for_xpos: true,
      ordered_groups,
      ordered_groups_with_vnodes,
      edges: [],
      edge_tail: [],
      edge_head: [],
      edge_reversed: [],
      ranks: Map::new(),
      intercluster_keys: Map::new(),
      cluster_parents: Map::new(),
      edge_vnodes: Map::new(),
      vnode_ranks: Map::new(),
      vnodes_by_rank: Map::new(),
      has_clusters: false,
      cluster_keys,
      vnode_clusters,
      vnode_sizes,
    },
    () => {
      let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
      sizes["a"] = sample_node_size(10.0, 10.0)
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
  assert_eq(seed.x_groups.get(0), Some([cluster_skeleton, "a", "v1"]))
  assert_eq(seed.x_cluster_keys.get(cluster_skeleton), Some("cluster_0"))
  assert_eq(seed.x_cluster_keys.get("a"), Some("cluster_0"))
  assert_eq(seed.x_cluster_keys.get("v1"), Some("cluster_0"))
}

///|
test "build_x_seed_data keeps base groups and sizes when vnode xpos mode is off" {
  let cluster_skeleton = @cluster_identity.cluster_skeleton_name("cluster_0", 0)

  let ordered_groups : Map[Int, Array[String]] = Map::new()
  ordered_groups[0] = [cluster_skeleton, "a"]

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["v1"] = sample_node_size(14.0, 6.0)

  let seed = build_x_seed_data(
    {
      use_vnodes_for_xpos: false,
      ordered_groups,
      ordered_groups_with_vnodes: Map::new(),
      edges: [],
      edge_tail: [],
      edge_head: [],
      edge_reversed: [],
      ranks: Map::new(),
      intercluster_keys: Map::new(),
      cluster_parents: Map::new(),
      edge_vnodes: Map::new(),
      vnode_ranks: Map::new(),
      vnodes_by_rank: Map::new(),
      has_clusters: true,
      cluster_keys: Map::new(),
      vnode_clusters: Map::new(),
      vnode_sizes,
    },
    () => {
      let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
      sizes["a"] = sample_node_size(10.0, 10.0)
      sizes
    },
    sizes => {
      let a_width = sizes.get("a").map(fn(s) { s.width_pt }).unwrap_or_default()
      let v1_width = sizes
        .get("v1")
        .map(fn(s) { s.width_pt })
        .unwrap_or_default()
      {
        x_edge_tail_port_x: [a_width],
        x_edge_head_port_x: [v1_width],
        x_edge_tail_port_order: [],
        x_edge_head_port_order: [],
        order_edge_tail_port_x: [],
        order_edge_head_port_x: [],
        order_edge_tail_port_order: [],
        order_edge_head_port_order: [],
      }
    },
  )

  assert_eq(seed.has_vnode_order, false)
  assert_eq(seed.x_groups.get(0), Some(["a"]))
  assert_eq(seed.x_order_sizes.length(), 1)
  assert_eq(seed.x_cluster_keys.length(), 0)
  assert_eq(seed.x_edge_tail_port_x, [10.0])
  assert_eq(seed.x_edge_head_port_x, [0.0])
}
