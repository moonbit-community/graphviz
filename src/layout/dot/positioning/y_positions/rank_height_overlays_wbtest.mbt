// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "build_all_ranks_with_overlays expands to cover inserted vnode ranks" {
  assert_eq(build_all_ranks_with_overlays([2, 3], [1, 5, 4]), [1, 2, 3, 4, 5])
  assert_eq(build_all_ranks_with_overlays([], [1, 5]), [])
}

///|
test "apply_rank_half_heights raises all rank height maps only where overlay is larger" {
  let rank_pht : Map[Int, Double] = Map::new()
  rank_pht[0] = 4.0
  rank_pht[1] = 6.0

  let rank_ht1 : Map[Int, Double] = Map::new()
  rank_ht1[0] = 3.0
  rank_ht1[1] = 7.0

  let rank_ht2 : Map[Int, Double] = Map::new()
  rank_ht2[0] = 5.0
  rank_ht2[1] = 2.0

  let overlays : Map[Int, Double] = Map::new()
  overlays[0] = 6.0
  overlays[1] = 4.0
  overlays[2] = 8.0

  apply_rank_half_heights(overlays, rank_pht, rank_ht1, rank_ht2)

  assert_eq(rank_pht.get(0), Some(6.0))
  assert_eq(rank_ht1.get(0), Some(6.0))
  assert_eq(rank_ht2.get(0), Some(6.0))

  assert_eq(rank_pht.get(1), Some(6.0))
  assert_eq(rank_ht1.get(1), Some(7.0))
  assert_eq(rank_ht2.get(1), Some(4.0))

  assert_eq(rank_pht.get(2), Some(8.0))
  assert_eq(rank_ht1.get(2), Some(8.0))
  assert_eq(rank_ht2.get(2), Some(8.0))
}

///|
test "apply_flat_label_rank_heights ignores missing vnode sizes and keeps max half height per rank" {
  let flat_label_ranks : Map[String, Int] = Map::new()
  flat_label_ranks["v0_small"] = 0
  flat_label_ranks["v0_large"] = 0
  flat_label_ranks["v1"] = 1
  flat_label_ranks["missing"] = 2

  let vnode_sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  vnode_sizes["v0_small"] = sample_node_size(10.0, 8.0)
  vnode_sizes["v0_large"] = sample_node_size(10.0, 20.0)
  vnode_sizes["v1"] = sample_node_size(10.0, 12.0)

  let rank_pht : Map[Int, Double] = Map::new()
  rank_pht[0] = 4.0
  rank_pht[1] = 7.0

  let rank_ht1 : Map[Int, Double] = Map::new()
  rank_ht1[0] = 3.0
  rank_ht1[1] = 5.0

  let rank_ht2 : Map[Int, Double] = Map::new()
  rank_ht2[0] = 1.0
  rank_ht2[1] = 8.0

  let overlay_ranks = apply_flat_label_rank_heights(
    flat_label_ranks, vnode_sizes, rank_pht, rank_ht1, rank_ht2,
  )

  assert_eq(rank_pht.get(0), Some(10.0))
  assert_eq(rank_ht1.get(0), Some(10.0))
  assert_eq(rank_ht2.get(0), Some(10.0))

  assert_eq(rank_pht.get(1), Some(7.0))
  assert_eq(rank_ht1.get(1), Some(6.0))
  assert_eq(rank_ht2.get(1), Some(8.0))

  assert_eq(rank_pht.get(2), None)
  assert_eq(overlay_ranks, [0, 0, 1])
}
