///|
/// Edge-label collision adjustment and bbox expansion helpers for cluster and
/// sibling-overlap postprocessing.

///|
fn collect_cluster_label_rects(
  graphs : Array[DotLayoutGraph],
  pad : Double,
) -> Array[@geom.Rect] {
  let rects : Array[@geom.Rect] = []
  for subgraph in graphs {
    match subgraph.label_pos {
      Some(pos) =>
        match graph_label_metrics(subgraph.graph) {
          Some(metrics) =>
            rects.push(
              rect_from_center(
                pos,
                metrics.width_pt,
                metrics.height_pt,
                pad,
              ),
            )
          None => ()
        }
      None => ()
    }
    let nested = collect_cluster_label_rects(subgraph.subgraphs, pad)
    for rect in nested {
      rects.push(rect)
    }
  }
  rects
}

///|
fn apply_edge_label_updates(
  graphs : Array[DotLayoutGraph],
  updates : Map[String, @geom.Point],
) -> Array[DotLayoutGraph] {
  let updated : Array[DotLayoutGraph] = []
  for graph in graphs {
    let edges = @routing.apply_label_updates_to_edges(graph.edges, updates)
    let subgraphs = apply_edge_label_updates(graph.subgraphs, updates)
    updated.push({
      graph: graph.graph,
      bbox: graph.bbox,
      label_pos: graph.label_pos,
      nodes: graph.nodes,
      edges,
      subgraphs,
    })
  }
  updated
}

///|
fn map_layout_subgraphs(
  subgraphs : Array[DotLayoutGraph],
  mapper : (DotLayoutGraph) -> DotLayoutGraph,
) -> Array[DotLayoutGraph] {
  let mapped : Array[DotLayoutGraph] = []
  for subgraph in subgraphs {
    mapped.push(mapper(subgraph))
  }
  mapped
}

///|
fn rebuild_layout_edges_subgraphs(
  layout : DotLayoutGraph,
  edges : Array[DotLayoutEdge],
  subgraphs : Array[DotLayoutGraph],
) -> DotLayoutGraph {
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges,
    subgraphs,
  }
}

///|
fn adjust_labels_for_clusters(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
) -> DotLayoutGraph {
  let pad = if nodesep_pt * 0.2 < 2.0 { 2.0 } else { nodesep_pt * 0.2 }
  let label_rects : Array[@geom.Rect] = []
  match layout.label_pos {
    Some(pos) =>
      match graph_label_metrics(layout.graph) {
        Some(metrics) =>
          label_rects.push(
            rect_from_center(pos, metrics.width_pt, metrics.height_pt, pad),
          )
        None => ()
      }
    None => ()
  }
  let subgraph_rects = collect_cluster_label_rects(layout.subgraphs, pad)
  for rect in subgraph_rects {
    label_rects.push(rect)
  }
  if label_rects.length() == 0 {
    let subgraphs =
      map_layout_subgraphs(
        layout.subgraphs,
        subgraph => adjust_labels_for_clusters(subgraph, nodesep_pt),
      )
    rebuild_layout_edges_subgraphs(layout, layout.edges, subgraphs)
  } else {
    let adjusted_labels =
      @routing.adjust_edge_label_positions(
        layout.edges,
        label_rects,
        pad,
        edge =>
          match @label_metrics.edge_mid_label_metrics(edge) {
            Some(metrics) => Some({ width: metrics.width, height: metrics.height })
            None => None
          },
      )
    let updated_subgraphs =
      apply_edge_label_updates(layout.subgraphs, adjusted_labels.updates)
    let subgraphs =
      map_layout_subgraphs(
        updated_subgraphs,
        subgraph => adjust_labels_for_clusters(subgraph, nodesep_pt),
      )
    rebuild_layout_edges_subgraphs(layout, adjusted_labels.edges, subgraphs)
  }
}

///|
fn adjust_labels_for_overlaps(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  let adjusted =
    @routing.adjust_edge_label_overlaps(
      layout.edges,
      nodesep_pt,
      rankdir,
      edge =>
        match @label_metrics.edge_mid_label_metrics(edge) {
          Some(metrics) => Some({ width: metrics.width, height: metrics.height })
          None => None
        },
      @routing.edge_tail_point_for_layout,
    )
  if adjusted.updates.length() == 0 {
    let subgraphs =
      map_layout_subgraphs(
        layout.subgraphs,
        subgraph => adjust_labels_for_overlaps(subgraph, nodesep_pt, rankdir),
      )
    rebuild_layout_edges_subgraphs(layout, layout.edges, subgraphs)
  } else {
    let updated_subgraphs =
      apply_edge_label_updates(layout.subgraphs, adjusted.updates)
    let subgraphs =
      map_layout_subgraphs(
        updated_subgraphs,
        subgraph => adjust_labels_for_overlaps(subgraph, nodesep_pt, rankdir),
      )
    rebuild_layout_edges_subgraphs(layout, adjusted.edges, subgraphs)
  }
}

///|
fn edge_label_adjust_enabled() -> Bool {
  @dot_shared.env_flag_enabled_nonempty(@sys.get_env_var("DOT_ADJUST_EDGE_LABELS"))
}

///|
/// Graphviz parity: label placement aligned to refs/graphviz/lib/common/labels.c (fixtures).
/// Xlabel placement lives in xlabel_layout.mbt (refs/graphviz/lib/label/xlabels.c).
/// Do not change behavior without updating fixtures/tests.
///|
fn rect_from_center(
  center : @geom.Point,
  width : Double,
  height : Double,
  pad : Double,
) -> @geom.Rect {
  let half_w = width / 2.0 + pad
  let half_h = height / 2.0 + pad
  {
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  }
}

///|
/// Edge-label bbox expansion helpers used in final postprocess.

///|
/// Graphviz parity: edge label bbox expansion aligned to refs/graphviz/lib/common/utils.c
/// (addLabelBB/compute_bb) + dotgen/dotsplines.c (updateBB for edge labels).
/// Do not change behavior without updating fixtures/tests.
fn expand_bbox_for_edge_labels(
  graph : @cgraph.Graph,
  layout : DotLayoutGraph,
  ranks : Map[String, Int],
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutGraph {
  if !graph.is_root() {
    return layout
  }
  let bbox =
    @routing.expand_bbox_for_edge_labels(
      {
        bbox: layout.bbox,
        edges: layout.edges,
        ranks,
        flat_label_edge_vnodes,
        rankdir: @dot_shared.graph_rankdir(graph),
      },
      {
        edge_mid_label_metrics_for:
          edge =>
            match @label_metrics.edge_mid_label_metrics(edge) {
              Some(metrics) => Some({ width: metrics.width, height: metrics.height })
              None => None
            },
        edge_label_metrics_for_attr:
          (edge, label_attr) =>
            match @label_metrics.edge_label_metrics_for_attr(edge, label_attr, true) {
              Some(metrics) => Some({ width: metrics.width, height: metrics.height })
              None => None
            },
        node_half_height_pt_for:
          (node, rankdir) => {
            let orientation = @dot_shared.record_layout_orientation(rankdir)
            @node_geometry.node_size(node, orientation).height_pt / 2.0
          },
      },
    )
  if bbox == layout.bbox {
    layout
  } else {
    {
      graph: layout.graph,
      bbox,
      label_pos: layout.label_pos,
      nodes: layout.nodes,
      edges: layout.edges,
      subgraphs: layout.subgraphs,
    }
  }
}

///|
/// Exterior edge-label nudge heuristic (DOT_ADJUST_EDGE_LABELS only).
fn adjust_edge_labels_if_enabled(
  layout : DotLayoutGraph,
  nodesep_pt : Double,
  rankdir : RankDir,
) -> DotLayoutGraph {
  if edge_label_adjust_enabled() {
    let adjusted_for_clusters =
      adjust_labels_for_clusters(layout, nodesep_pt)
    adjust_labels_for_overlaps(
      adjusted_for_clusters,
      nodesep_pt,
      rankdir,
    )
  } else {
    layout
  }
}
