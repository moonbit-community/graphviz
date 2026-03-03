///|
fn build_bezier_layout_edge(
  base : EdgeRouteBase,
  raw_bezier : Array[@geom.Point],
  label_pad_boost : Double,
  apply_dotted_adjustment : Bool,
  tail_swap : Bool,
  head_swap : Bool,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let bezier_layout_result =
    @routing.build_bezier_layout_spline_result(
      base,
      raw_bezier,
      label_pad_boost,
      apply_dotted_adjustment,
      tail_swap,
      head_swap,
    )
  build_edge_layout(
    base,
    bezier_layout_result.final_spline,
    bezier_layout_result.layout_spline_result,
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}

///|
/// Graphviz parity: self-edge routes reuse finalize/build_edge_layout path.
/// Do not change behavior without updating fixtures/tests.
fn build_self_edge_layout(
  base : EdgeRouteBase,
  route : SelfEdgeRoute,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let mut edge_layout =
    build_bezier_layout_edge(
      base,
      route.points,
      0.0,
      false,
      false,
      false,
      ranks,
      rank_y,
      vnode_info,
      vnode_positions,
      nodesep_pt,
      has_clusters,
      flat_label_edge_vnodes,
    )
  match route.label_pos {
    Some(pos) =>
      edge_layout = {
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos: Some(pos),
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
        xlabel_pos: edge_layout.xlabel_pos,
      }
    None => ()
  }
  edge_layout
}

///|
/// Graphviz parity: adjacent same-rank no-port/no-label multiedges use the
/// makeSimpleFlat spindle path (dotsplines.c).
/// Do not change behavior without updating fixtures/tests.
fn build_flat_adjacent_layout(
  base : EdgeRouteBase,
  bezier : Array[@geom.Point],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    base,
    bezier,
    0.0,
    false,
    base.swap_ends,
    base.swap_ends,
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}

///|
/// Graphviz parity: regular-edge reuse path keeps clipping/label finalization.
fn build_regular_bezier_layout(
  base : EdgeRouteBase,
  shared_spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  build_bezier_layout_edge(
    base,
    shared_spline_result.raw_bezier,
    shared_spline_result.label_pad_boost,
    shared_spline_result.apply_dotted_adjustment,
    base.swap_ends,
    base.swap_ends,
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}
