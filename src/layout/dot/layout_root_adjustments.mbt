///|
/// Root-level postprocess adjustment helpers.

///|
/// Graphviz parity: translate to origin aligned to refs/graphviz/lib/common/postproc.c
/// (translate_drawing/translate_bb).
/// Do not change behavior without updating fixtures/tests.
fn shift_layout_to_origin(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  if graph.is_root() {
    let dx = -layout.bbox.llx
    let dy = -layout.bbox.lly
    if dx != 0.0 || dy != 0.0 {
      shift_layout_graph(layout, dx, dy)
    } else {
      layout
    }
  } else {
    layout
  }
}

///|
/// Graphviz parity: root cluster padding aligned to refs/graphviz/lib/dotgen/position.c
/// (clust_ht/adjustRanks).
/// Do not change behavior without updating fixtures/tests.
fn apply_root_cluster_padding(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  root_cluster_pad_top : Double,
  root_cluster_pad_bottom : Double,
) -> DotLayoutGraph {
  if graph.is_root() &&
    (root_cluster_pad_top > 0.0 || root_cluster_pad_bottom > 0.0) {
    let padded = shift_layout_graph(layout, 0.0, root_cluster_pad_bottom)
    let padded_bbox : @geom.Rect = {
      llx: layout.bbox.llx,
      lly: layout.bbox.lly,
      urx: layout.bbox.urx,
      ury: layout.bbox.ury + root_cluster_pad_bottom + root_cluster_pad_top,
    }
    let label_pos =
      match root_label_pos_for_bbox(graph, padded_bbox) {
        Some(pos) => Some(pos)
        None => padded.label_pos
      }
    {
      graph: padded.graph,
      bbox: padded_bbox,
      label_pos,
      nodes: padded.nodes,
      edges: padded.edges,
      subgraphs: padded.subgraphs,
    }
  } else {
    layout
  }
}

///|
fn refresh_root_label_position(
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  if layout.graph.is_root() {
    let label_pos =
      match root_label_pos_for_bbox(layout.graph, layout.bbox) {
        Some(pos) => Some(pos)
        None => layout.label_pos
      }
    {
      graph: layout.graph,
      bbox: layout.bbox,
      label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    }
  } else {
    layout
  }
}

///|
/// Graphviz parity: final root-coordinate frame applies margin, then origin
/// translation, then root label refresh.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_coordinates(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
) -> DotLayoutGraph {
  let with_margin = {
    graph: layout.graph,
    bbox: apply_root_margin_x(graph, layout.bbox),
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs: layout.subgraphs,
  }
  refresh_root_label_position(
    shift_layout_to_origin(graph, with_margin),
  )
}
