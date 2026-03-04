///|
/// Final-layout ratio=fill scaling helpers used by postprocess.

///|
fn scale_layout_point_rounded(
  point : @geom.Point,
  sx : Double,
  sy : Double,
) -> @geom.Point {
  let scaled = scale_point_value(point, sx, sy)
  { x: scaled.x.round(), y: scaled.y.round() }
}

///|
fn scale_layout_graph(
  layout : DotLayoutGraph,
  sx : Double,
  sy : Double,
  round_node_pos : Bool,
) -> DotLayoutGraph {
  let nodes : Array[DotLayoutNode] = []
  for node_layout in layout.nodes {
    let scaled_pos =
      if round_node_pos {
        scale_layout_point_rounded(node_layout.pos, sx, sy)
      } else {
        scale_point_value(node_layout.pos, sx, sy)
      }
    nodes.push({
      node: node_layout.node,
      pos: scaled_pos,
      width_in: node_layout.width_in,
      height_in: node_layout.height_in,
      label_pos: scale_optional_point_value(node_layout.label_pos, sx, sy),
      xlabel_pos: scale_optional_point_value(node_layout.xlabel_pos, sx, sy),
    })
  }
  let edges : Array[DotLayoutEdge] = []
  for edge_layout in layout.edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(scale_spline_value(spline, sx, sy))
    }
    edges.push({
      edge: edge_layout.edge,
      splines,
      label_pos: scale_optional_point_value(edge_layout.label_pos, sx, sy),
      head_label_pos: scale_optional_point_value(
        edge_layout.head_label_pos,
        sx,
        sy,
      ),
      tail_label_pos: scale_optional_point_value(
        edge_layout.tail_label_pos,
        sx,
        sy,
      ),
      xlabel_pos: scale_optional_point_value(edge_layout.xlabel_pos, sx, sy),
    })
  }
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(scale_layout_graph(subgraph, sx, sy, round_node_pos))
  }
  {
    graph: layout.graph,
    bbox: {
      llx: layout.bbox.llx * sx,
      lly: layout.bbox.lly * sy,
      urx: layout.bbox.urx * sx,
      ury: layout.bbox.ury * sy,
    },
    label_pos: scale_optional_point_value(layout.label_pos, sx, sy),
    nodes,
    edges,
    subgraphs,
  }
}

///|
/// Graphviz parity: root ratio=fill scaling aligned to refs/graphviz/lib/dotgen/position.c
/// (set_aspect R_FILL branch + ND_coord rounding).
fn apply_ratio_fill_scale(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  rankdir : RankDir,
  ratio_bbox : @geom.Rect,
) -> DotLayoutGraph {
  if !graph.is_root() {
    return layout
  }
  match ratio_fill_scale_factors(graph, ratio_bbox, rankdir) {
    Some(scale_factors) => {
      if scale_factors.sx == 1.0 && scale_factors.sy == 1.0 {
        layout
      } else {
        // Graphviz parity: set_aspect rounds ND_coord after scaling.
        scale_layout_graph(layout, scale_factors.sx, scale_factors.sy, true)
      }
    }
    None => layout
  }
}
