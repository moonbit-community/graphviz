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
test "node_half_height_pt prefers larger self-edge label half height" {
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["a"] = sample_node_size(20.0, 30.0)

  let self_edge_labels : Map[String, Double] = Map::new()
  self_edge_labels["a"] = 18.0
  self_edge_labels["b"] = 7.0

  assert_eq(node_half_height_pt("a", sizes, self_edge_labels), 18.0)
  assert_eq(node_half_height_pt("b", sizes, self_edge_labels), 7.0)
  assert_eq(node_half_height_pt("c", sizes, self_edge_labels), 0.0)
}

///|
test "self_edge_label_half_heights keeps the maximum per tail and ignores non-self edges" {
  let graph = @cgraph.Graph::new(
    @cgraph.GraphKind::Directed,
    name="g",
    strict=false,
  )
  let a = graph.node("a")
  let b = graph.node("b")
  let aa_1 = graph.edge(a, a)
  aa_1.set_attr("fixture_id", "aa_1")
  let ab = graph.edge(a, b)
  ab.set_attr("fixture_id", "ab")
  let aa_2 = graph.edge(a, a)
  aa_2.set_attr("fixture_id", "aa_2")
  let bb = graph.edge(b, b)
  bb.set_attr("fixture_id", "bb")

  let heights = self_edge_label_half_heights([aa_1, ab, aa_2, bb], edge => {
    match edge.get_attr("fixture_id") {
      Some("aa_1") => 10.0
      Some("aa_2") => 18.0
      Some("bb") => 14.0
      _ => 30.0
    }
  })

  assert_eq(heights.get("a"), Some(9.0))
  assert_eq(heights.get("b"), Some(7.0))
  assert_eq(heights.length(), 2)
}

///|
test "fill_rank_positions uses the larger of ranksep spacing and cluster margin spacing" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["low"]
  groups[1] = ["mid"]
  groups[2] = ["high"]

  let rank_pht : Map[Int, Double] = Map::new()
  rank_pht[0] = 2.0
  rank_pht[1] = 3.0
  rank_pht[2] = 4.0

  let rank_ht1 : Map[Int, Double] = Map::new()
  rank_ht1[0] = 4.0
  rank_ht1[1] = 2.0
  rank_ht1[2] = 5.0

  let rank_ht2 : Map[Int, Double] = Map::new()
  rank_ht2[0] = 1.0
  rank_ht2[1] = 6.0
  rank_ht2[2] = 3.0

  let y_positions : Map[String, Double] = Map::new()
  let rank_y : Map[Int, Double] = Map::new()
  fill_rank_positions({
    rank_keys: [0, 1, 2],
    groups,
    all_ranks: [0, 1, 2],
    rank_pht,
    rank_ht1,
    rank_ht2,
    ranksep_pt: 5.0,
    y_positions,
    rank_y,
  })

  assert_eq(rank_y.get(2), Some(5.0))
  assert_eq(rank_y.get(1), Some(18.0))
  assert_eq(rank_y.get(0), Some(36.0))
  assert_eq(y_positions.get("high"), Some(5.0))
  assert_eq(y_positions.get("mid"), Some(18.0))
  assert_eq(y_positions.get("low"), Some(36.0))
}
