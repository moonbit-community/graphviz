// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "cluster name helpers build and recognize skeleton and boundary prefixes" {
  let skeleton = cluster_skeleton_name("cluster_a", 3)
  let left = cluster_left_boundary_name("cluster_a")
  let right = cluster_right_boundary_name("cluster_a")

  assert_eq(skeleton, "\{CLUSTER_SKELETON_PREFIX}cluster_a@3")
  assert_true(is_cluster_skeleton_name(skeleton))
  assert_false(is_cluster_skeleton_name(left))

  assert_eq(left, "\{CLUSTER_LN_PREFIX}cluster_a")
  assert_eq(right, "\{CLUSTER_RN_PREFIX}cluster_a")
  assert_true(is_cluster_boundary_name(left))
  assert_true(is_cluster_boundary_name(right))
  assert_true(is_cluster_left_boundary_name(left))
  assert_false(is_cluster_left_boundary_name(right))
}

///|
test "unique_cluster_boundary_name keeps base then adds numeric suffixes" {
  let existing : Map[String, Bool] = Map::new()

  let first = unique_cluster_boundary_name("_mbt_cluster_ln_group", existing)
  let second = unique_cluster_boundary_name("_mbt_cluster_ln_group", existing)
  let third = unique_cluster_boundary_name("_mbt_cluster_ln_group", existing)

  assert_eq(first, "_mbt_cluster_ln_group")
  assert_eq(second, "_mbt_cluster_ln_group_1")
  assert_eq(third, "_mbt_cluster_ln_group_2")
}

///|
test "cluster_key_from_boundary prefers exact and then longest numeric suffix match" {
  let cluster_names : Map[String, Bool] = {
    "cluster": true,
    "cluster_long": true,
    "other": true,
  }

  assert_eq(
    cluster_key_from_boundary("\{CLUSTER_LN_PREFIX}cluster_long", cluster_names),
    Some("cluster_long"),
  )
  assert_eq(
    cluster_key_from_boundary(
      "\{CLUSTER_RN_PREFIX}cluster_long_2",
      cluster_names,
    ),
    Some("cluster_long"),
  )
  assert_eq(
    cluster_key_from_boundary("\{CLUSTER_LN_PREFIX}cluster_9", cluster_names),
    Some("cluster"),
  )
  assert_eq(
    cluster_key_from_boundary(
      "\{CLUSTER_LN_PREFIX}cluster_long_extra",
      cluster_names,
    ),
    None,
  )
  assert_eq(cluster_key_from_boundary("plain_node", cluster_names), None)
}

///|
test "cluster_key_from_skeleton extracts the cluster portion before rank suffix" {
  let skeleton = cluster_skeleton_name("cluster_a", 7)
  assert_eq(cluster_key_from_skeleton(skeleton), Some("cluster_a"))
  assert_eq(cluster_key_from_skeleton("plain_node"), None)
}
