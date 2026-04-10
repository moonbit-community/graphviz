// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


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
