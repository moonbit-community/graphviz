// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn assert_double_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_true(Double::is_close(actual, expected, absolute_tolerance=eps))
}

///|
test "compute_cluster_bbox_heights accumulates local, nested, margin, and label padding contributions" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let outer = root.subgraph(name="cluster_outer")
  let inner = outer.subgraph(name="cluster_inner")
  let a = outer.node("a")
  let b = inner.node("b")
  ignore(a)
  ignore(b)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 1
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  let self_edge_labels : Map[String, Double] = Map::new()

  let heights = compute_cluster_bbox_heights({
    graph: root,
    ranks,
    sizes,
    self_edge_labels,
    rankdir: @rankdir.RankDir::TB,
    cluster_margin_pt_for: graph => {
      match graph.name() {
        Some("cluster_outer") => 2.0
        Some("cluster_inner") => 1.0
        _ => 0.0
      }
    },
    cluster_label_padding_for: (graph, _rankdir) => {
      match graph.name() {
        Some("cluster_outer") => { top: 5.0, bottom: 7.0 }
        Some("cluster_inner") => { top: 1.0, bottom: 3.0 }
        _ => { top: 0.0, bottom: 0.0 }
      }
    },
    node_half_height_pt_for: (name, _sizes, _labels) => {
      if name == "a" {
        2.0
      } else {
        4.0
      }
    },
  })

  let outer_heights = match heights.get("cluster_outer") {
    Some(value) => value
    None => fail("missing outer cluster heights")
  }
  let inner_heights = match heights.get("cluster_inner") {
    Some(value) => value
    None => fail("missing inner cluster heights")
  }

  assert_eq(heights.length(), 2)
  assert_eq(inner_heights.ht1, 8.0)
  assert_eq(inner_heights.ht2, 6.0)
  assert_eq(outer_heights.ht1, 17.0)
  assert_eq(outer_heights.ht2, 9.0)
}

///|
test "adjust_flip_rank_heights widens rank spacing and updates cluster half-heights when labels do not fit" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let a = cluster.node("a")
  let b = cluster.node("b")
  ignore(a)
  ignore(b)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 1
  ranks["b"] = 3
  let rank_y : Map[Int, Double] = Map::new()
  rank_y[0] = 120.0
  rank_y[1] = 100.0
  rank_y[2] = 60.0
  rank_y[3] = 20.0
  let rank_ht1 : Map[Int, Double] = Map::new()
  rank_ht1[3] = 5.0
  let rank_ht2 : Map[Int, Double] = Map::new()
  rank_ht2[1] = 5.0
  let cluster_heights : Map[String, ClusterBboxHeightPair] = Map::new()

  let changed = adjust_flip_rank_heights({
    graph: root,
    ranks,
    rank_y,
    rank_ht1,
    rank_ht2,
    cluster_heights,
    min_root_rank: 0,
    margin_total: 0.0,
    cluster_margin_pt_for: _graph => 0.0,
    cluster_label_width_pt_for: graph => {
      match graph.name() {
        Some("cluster_0") => Some(100.0)
        _ => None
      }
    },
  })

  let updated = match cluster_heights.get("cluster_0") {
    Some(value) => value
    None => fail("missing updated cluster heights")
  }

  assert_true(changed)
  assert_double_close(rank_y.get(3).unwrap_or_default(), 25.5)
  assert_double_close(rank_y.get(2).unwrap_or_default(), 65.5)
  assert_double_close(rank_y.get(1).unwrap_or_default(), 105.5)
  assert_double_close(rank_y.get(0).unwrap_or_default(), 130.0)
  assert_double_close(rank_ht1.get(3).unwrap_or_default(), 10.5)
  assert_double_close(rank_ht2.get(1).unwrap_or_default(), 9.5)
  assert_double_close(updated.ht1, 10.5)
  assert_double_close(updated.ht2, 9.5)
}

///|
test "adjust_flip_rank_heights leaves state unchanged when clusters have no width constraint" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let a = cluster.node("a")
  ignore(a)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 1
  let rank_y : Map[Int, Double] = Map::new()
  rank_y[1] = 42.0
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  let cluster_heights : Map[String, ClusterBboxHeightPair] = Map::new()

  let changed = adjust_flip_rank_heights({
    graph: root,
    ranks,
    rank_y,
    rank_ht1,
    rank_ht2,
    cluster_heights,
    min_root_rank: 0,
    margin_total: 0.0,
    cluster_margin_pt_for: _graph => 0.0,
    cluster_label_width_pt_for: _graph => None,
  })

  assert_false(changed)
  assert_eq(rank_y.get(1), Some(42.0))
  assert_true(cluster_heights.get("cluster_0") is None)
}
