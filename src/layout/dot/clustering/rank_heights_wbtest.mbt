///|
fn assert_rank_height_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  assert_true(Double::is_close(actual, expected, absolute_tolerance=eps))
}

///|
test "apply_cluster_rank_heights propagates nested cluster heights into rank half-heights" {
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
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()

  apply_cluster_rank_heights({
    graph: root,
    ranks,
    sizes,
    self_edge_labels,
    rank_ht1,
    rank_ht2,
    rankdir: @rankdir.RankDir::TB,
    cluster_margin_pt_for: graph =>
      match graph.name() {
        Some("cluster_outer") => 2.0
        Some("cluster_inner") => 1.0
        _ => 0.0
      },
    cluster_label_padding_for: (graph, _rankdir) =>
      match graph.name() {
        Some("cluster_outer") => { top: 5.0, bottom: 7.0 }
        Some("cluster_inner") => { top: 1.0, bottom: 3.0 }
        _ => { top: 0.0, bottom: 0.0 }
      },
    node_half_height_pt_for: (name, _sizes, _labels) => if name == "a" { 2.0 } else { 4.0 },
  })

  assert_rank_height_close(rank_ht1.get(1).unwrap_or_default(), 17.0)
  assert_rank_height_close(rank_ht2.get(0).unwrap_or_default(), 9.0)
  assert_rank_height_close(rank_ht2.get(1).unwrap_or_default(), 6.0)
  assert_true(rank_ht1.get(0) is None)
}

///|
test "apply_cluster_rank_heights preserves larger existing rank half-heights" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let a = cluster.node("a")
  ignore(a)

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 1
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  let self_edge_labels : Map[String, Double] = Map::new()
  let rank_ht1 : Map[Int, Double] = Map::new()
  let rank_ht2 : Map[Int, Double] = Map::new()
  rank_ht1[1] = 10.0
  rank_ht2[1] = 9.0

  apply_cluster_rank_heights({
    graph: root,
    ranks,
    sizes,
    self_edge_labels,
    rank_ht1,
    rank_ht2,
    rankdir: @rankdir.RankDir::TB,
    cluster_margin_pt_for: _graph => 0.0,
    cluster_label_padding_for: (_graph, _rankdir) => { top: 0.0, bottom: 0.0 },
    node_half_height_pt_for: (_name, _sizes, _labels) => 2.0,
  })

  assert_rank_height_close(rank_ht1.get(1).unwrap_or_default(), 10.0)
  assert_rank_height_close(rank_ht2.get(1).unwrap_or_default(), 9.0)
}
