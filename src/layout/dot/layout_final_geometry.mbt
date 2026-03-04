///|
/// Final geometry and subgraph-bbox helpers for postprocess.

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
priv struct FinalLayoutGeometry {
  final_nodes : Array[DotLayoutNode]
  final_edges : Array[DotLayoutEdge]
  rank_bbox : @geom.Rect
}

///|
/// Graphviz parity: base layout bbox aligned to refs/graphviz/lib/dotgen/position.c
/// (dot_compute_bb).
/// Do not change behavior without updating fixtures/tests.
fn build_final_layout_geometry(
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
  all_ranks : Array[Int],
  sizes : Map[String, NodeSize],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> FinalLayoutGeometry {
  let base_bbox = compute_dot_bbox(
    nodes_out,
    all_ranks,
    sizes,
    rank_y,
    rank_ht1,
    rank_ht2,
  )
  { final_nodes: nodes_out, final_edges: edges_out, rank_bbox: base_bbox }
}

///|
/// Graphviz parity: cluster bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
priv struct SubgraphsAndBBox {
  subgraphs : Array[DotLayoutGraph]
  base_bbox : @geom.Rect
}

///|
/// Graphviz parity: cluster bbox expansion aligned to refs/graphviz/lib/common/postproc.c
/// (place_graph_label) + dotgen/position.c (cluster margins).
/// Do not change behavior without updating fixtures/tests.
fn build_subgraphs_and_bbox(
  graph : @cgraph.Graph,
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
  bbox : @geom.Rect,
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair],
  rankdir : RankDir,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> SubgraphsAndBBox {
  let subgraphs =
    layout_subgraphs(
      graph,
      nodes,
      edges,
      cluster_ln_x,
      cluster_rn_x,
      cluster_bbox_heights,
      rankdir,
      ranks,
      rank_y,
      rank_ht1,
      rank_ht2,
    )
  let expanded = if subgraphs.length() > 0 {
    expand_bbox_with_clusters(bbox, subgraphs)
  } else {
    bbox
  }
  { subgraphs, base_bbox: expanded }
}
