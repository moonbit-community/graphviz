// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "single rank crossing minimization includes virtual and skeleton anchors" {
  let virtual_node = "_mbt_edge_vn_0_1"
  let skeleton = "_mbt_cluster_skel_cluster_child@1"
  for other in [virtual_node, skeleton, "real"] {
    @test.assert_eq(
      has_single_rank_incidents(["a"], ["a"], [other], [1], Map([]), Map([])),
      true,
    )
    @test.assert_eq(
      has_single_rank_incidents(["a"], [other], ["a"], [1], Map([]), Map([])),
      true,
    )
    @test.assert_eq(
      has_single_rank_incidents(["a"], [], [], [], { "a": [other] }, Map([])),
      true,
    )
    @test.assert_eq(
      has_single_rank_incidents(["a"], [], [], [], Map([]), { "a": [other] }),
      true,
    )
  }
  @test.assert_eq(
    has_single_rank_incidents(
      ["a"],
      ["a"],
      [virtual_node],
      [0],
      Map([]),
      Map([]),
    ),
    false,
  )
  @test.assert_eq(
    has_single_rank_incidents(["a", "b"], ["a"], ["b"], [1], Map([]), Map([])),
    false,
  )
}
