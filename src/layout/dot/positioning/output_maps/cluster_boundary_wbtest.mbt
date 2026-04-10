// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_cluster_boundary_x collects left and right boundary nodes" {
  let cluster_names : Map[String, Bool] = Map::new()
  cluster_names["cluster0"] = true

  let x_positions : Map[String, Double] = Map::new()
  x_positions[@cluster_identity.cluster_left_boundary_name("cluster0")] = 12.0
  x_positions[@cluster_identity.cluster_right_boundary_name("cluster0")] = 48.0
  x_positions["plain"] = 99.0

  let output = build_cluster_boundary_x({
    has_clusters: true,
    x_positions,
    is_cluster_boundary: name => {
      @cluster_identity.is_cluster_boundary_name(name)
    },
    boundary_cluster_key: name => {
      @cluster_identity.cluster_key_from_boundary(name, cluster_names)
    },
    is_left_boundary: name => {
      @cluster_identity.is_cluster_left_boundary_name(name)
    },
  })

  assert_eq(output.cluster_ln_x.get("cluster0"), Some(12.0))
  assert_eq(output.cluster_rn_x.get("cluster0"), Some(48.0))
  assert_eq(output.cluster_ln_x.length(), 1)
  assert_eq(output.cluster_rn_x.length(), 1)
}
