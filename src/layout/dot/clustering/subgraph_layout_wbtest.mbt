
///|
fn cluster_test_node_layout(
  node : @cgraph.Node,
  pos : @geom.Point,
  width_in : Double,
  height_in : Double,
) -> DotLayoutNode {
  { node, pos, width_in, height_in, label_pos: None, xlabel_pos: None }
}

///|
fn cluster_test_layout_tree(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  subgraphs? : Array[LayoutTree] = [],
) -> LayoutTree {
  { graph, bbox, label_pos: None, nodes: [], edges: [], subgraphs }
}

///|
test "expand_bbox_with_subgraphs and expand_bbox_with_clusters recurse by responsibility" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  let plain = root.subgraph(name="group_0")
  let nested_cluster = plain.subgraph(name="cluster_1")

  let subgraphs = [
    cluster_test_layout_tree(
      cluster,
      { llx: 20.0, lly: 5.0, urx: 30.0, ury: 15.0 },
    ),
    cluster_test_layout_tree(
      plain,
      { llx: -5.0, lly: 2.0, urx: -1.0, ury: 4.0 },
      subgraphs=[
        cluster_test_layout_tree(
          nested_cluster,
          { llx: 50.0, lly: 1.0, urx: 60.0, ury: 9.0 },
        ),
      ],
    ),
  ]
  let bbox : @geom.Rect = { llx: 0.0, lly: 0.0, urx: 10.0, ury: 10.0 }

  assert_eq(
    expand_bbox_with_subgraphs(bbox, subgraphs),
    { llx: -5.0, lly: 0.0, urx: 60.0, ury: 15.0 },
  )
  assert_eq(
    expand_bbox_with_clusters(bbox, subgraphs),
    { llx: 0.0, lly: 0.0, urx: 68.0, ury: 15.0 },
  )
}

///|
test "layout_subgraphs omits empty clusters and uses rank plus x constraints for cluster bbox" {
  let root = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = root.subgraph(name="cluster_0")
  cluster.set_attr("label", "Cluster")
  let empty = root.subgraph(name="cluster_empty")
  empty.set_attr("label", "Empty")
  let a = cluster.node("a")
  ignore(a)

  let nodes_out = [
    cluster_test_node_layout(a, { x: 10.0, y: 20.0 }, 1.0, 1.0),
  ]
  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 1
  let rank_y : Map[Int, Double] = Map::new()
  rank_y[1] = 100.0
  let rank_ht1 : Map[Int, Double] = Map::new()
  rank_ht1[1] = 5.0
  let rank_ht2 : Map[Int, Double] = Map::new()
  rank_ht2[1] = 7.0
  let cluster_ln_x : Map[String, Double] = Map::new()
  cluster_ln_x["cluster_0"] = 2.0
  let cluster_rn_x : Map[String, Double] = Map::new()
  cluster_rn_x["cluster_0"] = 18.0
  let cluster_bbox_heights : Map[String, ClusterBboxHeightPair] = Map::new()
  cluster_bbox_heights["cluster_0"] = { ht1: 9.0, ht2: 11.0 }

  let layouts = layout_subgraphs({
    graph: root,
    nodes_out,
    edges_out: [],
    cluster_ln_x,
    cluster_rn_x,
    cluster_bbox_heights,
    rankdir: @rankdir.RankDir::TB,
    ranks,
    rank_y,
    rank_ht1,
    rank_ht2,
  })

  assert_eq(layouts.length(), 1)
  assert_eq(layouts[0].graph.name(), Some("cluster_0"))
  assert_eq(layouts[0].bbox, { llx: 2.0, lly: 91.0, urx: 18.0, ury: 111.0 })

  let metrics = match @label_metrics.graph_label_metrics(cluster) {
    Some(value) => value
    None => fail("expected cluster label metrics")
  }
  let pad = CLUSTER_LABEL_PAD_PT
  let expected_label_pos = @shared.graph_label_pos(
    layouts[0].bbox,
    metrics.width_pt + pad * 2.0,
    metrics.height_pt + pad,
    @shared.graph_label_loc(cluster),
    @shared.graph_label_just(cluster),
  )
  assert_eq(layouts[0].label_pos, Some(expected_label_pos))
}
