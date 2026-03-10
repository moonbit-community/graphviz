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

///|
test "build_y_positions_from_rank_groups rebuilds node positions from updated rank y values" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["low_a", "low_b"]
  groups[2] = ["high"]

  let rank_y : Map[Int, Double] = Map::new()
  rank_y[0] = 30.0
  rank_y[2] = 5.0

  let y_positions = build_y_positions_from_rank_groups([2, 0], groups, rank_y)

  assert_eq(y_positions.get("high"), Some(5.0))
  assert_eq(y_positions.get("low_a"), Some(30.0))
  assert_eq(y_positions.get("low_b"), Some(30.0))
}

///|
test "build_y_positions_with_flip rebuilds node y positions after cluster flip adjustment" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let a = cluster.node("a")
  let b = cluster.node("b")
  ignore(a)
  ignore(b)

  let rank_keys = [1, 3]
  let y_all_ranks = [0, 1, 2, 3]

  let groups : Map[Int, Array[String]] = Map::new()
  groups[1] = ["a"]
  groups[3] = ["b"]

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 1
  ranks["b"] = 3

  let initial_rank_pht : Map[Int, Double] = Map::new()
  let initial_rank_ht1 : Map[Int, Double] = Map::new()
  initial_rank_ht1[3] = 5.0
  let initial_rank_ht2 : Map[Int, Double] = Map::new()
  initial_rank_ht2[1] = 5.0
  let initial_y_positions : Map[String, Double] = Map::new()
  let initial_rank_y : Map[Int, Double] = Map::new()
  fill_rank_positions({
    rank_keys,
    groups,
    all_ranks: y_all_ranks,
    rank_pht: initial_rank_pht,
    rank_ht1: initial_rank_ht1,
    rank_ht2: initial_rank_ht2,
    ranksep_pt: 10.0,
    y_positions: initial_y_positions,
    rank_y: initial_rank_y,
  })

  let solve_rank_pht : Map[Int, Double] = Map::new()
  let solve_rank_ht1 : Map[Int, Double] = Map::new()
  solve_rank_ht1[3] = 5.0
  let solve_rank_ht2 : Map[Int, Double] = Map::new()
  solve_rank_ht2[1] = 5.0
  let cluster_bbox_heights : Map[
    String,
    @cluster_geometry.ClusterBboxHeightPair,
  ] = Map::new()

  let output = build_y_positions_with_flip({
    graph: root,
    rankdir: @rankdir.RankDir::LR,
    rank_keys,
    groups,
    ranks,
    rank_pht: solve_rank_pht,
    rank_ht1: solve_rank_ht1,
    rank_ht2: solve_rank_ht2,
    ranksep_pt: 10.0,
    cluster_bbox_heights,
    y_all_ranks,
    cluster_margin_pt_for: _graph => 0.0,
    cluster_label_width_pt_for: graph => {
      match graph.name() {
        Some("cluster_0") => Some(40.0)
        _ => None
      }
    },
  })

  assert_eq(initial_y_positions.get("a"), Some(25.0))
  assert_eq(initial_y_positions.get("b"), Some(5.0))

  assert_true(output.rank_y.get(1) != initial_rank_y.get(1))
  assert_true(output.rank_y.get(3) != initial_rank_y.get(3))
  assert_eq(output.rank_y.get(0), Some(48.0))
  assert_eq(output.rank_y.get(1), Some(30.5))
  assert_eq(output.rank_y.get(2), Some(20.5))
  assert_eq(output.rank_y.get(3), Some(10.5))
  assert_eq(output.y_positions.get("a"), output.rank_y.get(1))
  assert_eq(output.y_positions.get("b"), output.rank_y.get(3))
  assert_true(output.y_positions.get("a") != initial_y_positions.get("a"))
  assert_true(output.y_positions.get("b") != initial_y_positions.get("b"))
}
