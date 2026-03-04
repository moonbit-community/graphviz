///|
/// Final geometry helpers for postprocess.

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
