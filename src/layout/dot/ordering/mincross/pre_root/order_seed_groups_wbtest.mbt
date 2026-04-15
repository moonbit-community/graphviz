// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_order_seed_groups merges vnode groups and appends cluster skeletons in cluster order before unseen clusters" {
  let ordering_groups_base : Map[Int, Array[String]] = Map::new()
  ordering_groups_base[0] = ["a"]
  ordering_groups_base[1] = ["b"]

  let base_order_index : Map[String, Int] = Map::new()
  base_order_index["a"] = 0
  base_order_index["b"] = 0

  let cluster_keys : Map[String, String] = Map::new()
  cluster_keys["a"] = "cluster_x"
  cluster_keys["b"] = "cluster_y"

  let cluster_min_rank : Map[String, Int] = Map::new()
  cluster_min_rank["cluster_y"] = 1
  cluster_min_rank["cluster_x"] = 0
  cluster_min_rank["cluster_z"] = 1

  let cluster_max_rank : Map[String, Int] = Map::new()
  cluster_max_rank["cluster_x"] = 1
  cluster_max_rank["cluster_z"] = 1

  let vnode_clusters : Map[String, String] = Map::new()
  vnode_clusters["v0"] = "cluster_x"

  let vnodes_by_rank : Map[Int, Array[String]] = Map::new()
  vnodes_by_rank[0] = ["v0"]

  let vnode_order_keys_for_ordering : Map[String, Double] = Map::new()
  vnode_order_keys_for_ordering["v0"] = 0.5

  let order_sizes : Map[String, NodeSize] = Map::new()
  order_sizes["a"] = @node_primitives.node_size_from_points(10.0, 8.0)
  order_sizes["b"] = @node_primitives.node_size_from_points(12.0, 9.0)

  let vnode_sizes : Map[String, NodeSize] = Map::new()
  vnode_sizes["v0"] = @node_primitives.vnode_size_from_widths_with_h(
    2.0, 3.0, 4.0,
  )

  let skeleton_size = @node_primitives.node_size_from_points(6.0, 6.0)

  let seeded = build_order_seed_groups({
    ordering_groups_base,
    base_order_index,
    order_with_vnodes: true,
    order_with_clusters: true,
    cluster_keys,
    cluster_order: ["cluster_y", "cluster_x"],
    cluster_min_rank,
    cluster_max_rank,
    vnode_clusters,
    vnodes_by_rank,
    vnode_order_keys_for_ordering,
    order_sizes,
    vnode_sizes,
    skeleton_size,
  })

  let skel_x_0 = @cluster_identity.cluster_skeleton_name("cluster_x", 0)
  let skel_x_1 = @cluster_identity.cluster_skeleton_name("cluster_x", 1)
  let skel_y_1 = @cluster_identity.cluster_skeleton_name("cluster_y", 1)
  let skel_z_1 = @cluster_identity.cluster_skeleton_name("cluster_z", 1)

  assert_eq(seeded.order_groups.get(0), Some(["a", "v0", skel_x_0]))
  assert_eq(
    seeded.order_groups.get(1),
    Some(["b", skel_y_1, skel_x_1, skel_z_1]),
  )
  assert_eq(seeded.order_cluster_keys.get("a"), Some("cluster_x"))
  assert_eq(seeded.order_cluster_keys.get("b"), Some("cluster_y"))
  assert_eq(seeded.order_cluster_keys.get("v0"), Some("cluster_x"))
  assert_eq(seeded.order_cluster_keys.get(skel_x_0), Some("cluster_x"))
  assert_eq(seeded.order_cluster_keys.get(skel_y_1), Some("cluster_y"))
  assert_eq(seeded.order_cluster_keys.get(skel_z_1), Some("cluster_z"))
  assert_eq(seeded.order_cluster_skeleton.get(skel_x_0), Some(true))
  assert_eq(seeded.order_cluster_skeleton.get(skel_x_1), Some(true))
  assert_eq(seeded.order_cluster_skeleton.get(skel_y_1), Some(true))
  assert_eq(seeded.order_cluster_skeleton.get(skel_z_1), Some(true))
  assert_eq(
    seeded.order_sizes_out.get("v0").map(fn(size) { size.width_pt }),
    Some(5.0),
  )
  assert_eq(
    seeded.order_sizes_out.get(skel_x_0).map(fn(size) { size.height_pt }),
    Some(6.0),
  )
}

///|
test "build_order_seed_groups keeps only real-node metadata when vnode and cluster ordering are disabled" {
  let ordering_groups_base : Map[Int, Array[String]] = Map::new()
  ordering_groups_base[0] = ["a", "b"]

  let order_sizes : Map[String, NodeSize] = Map::new()
  order_sizes["a"] = @node_primitives.node_size_from_points(10.0, 8.0)
  order_sizes["b"] = @node_primitives.node_size_from_points(12.0, 9.0)

  let seeded = build_order_seed_groups({
    ordering_groups_base,
    base_order_index: Map::new(),
    order_with_vnodes: false,
    order_with_clusters: false,
    cluster_keys: { "a": "cluster_a" },
    cluster_order: ["cluster_a"],
    cluster_min_rank: { "cluster_a": 0 },
    cluster_max_rank: { "cluster_a": 0 },
    vnode_clusters: { "v0": "cluster_a" },
    vnodes_by_rank: { 0: ["v0"] },
    vnode_order_keys_for_ordering: { "v0": 0.5 },
    order_sizes,
    vnode_sizes: {
      "v0": @node_primitives.vnode_size_from_widths_with_h(2.0, 3.0, 4.0),
    },
    skeleton_size: @node_primitives.node_size_from_points(6.0, 6.0),
  })

  match seeded.order_groups.get(0) {
    Some(list) => list[0] = "mutated"
    None => fail("missing seeded rank")
  }

  assert_eq(ordering_groups_base.get(0), Some(["a", "b"]))
  assert_eq(seeded.order_groups.get(0), Some(["mutated", "b"]))
  assert_eq(seeded.order_cluster_keys, { "a": "cluster_a" })
  assert_eq(seeded.order_cluster_skeleton.length(), 0)
  assert_true(seeded.order_sizes_out.get("v0") is None)
  assert_eq(
    seeded.order_sizes_out.get("a").map(fn(size) { size.width_pt }),
    Some(10.0),
  )
}
