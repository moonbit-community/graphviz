///|
/// Edge-label bbox expansion helpers used in final postprocess.

///|
priv struct LabelExtent {
  width : Double
  height : Double
}

fn expand_bbox_for_label_pos(
  bbox : @geom.Rect,
  pos : @geom.Point?,
  metrics : LabelExtent?,
) -> @geom.Rect {
  match (pos, metrics) {
    (Some(center), Some(extent)) => {
      let half_w = extent.width / 2.0
      let half_h = extent.height / 2.0
      let min_x = center.x - half_w
      let max_x = center.x + half_w
      let min_y = center.y - half_h
      let max_y = center.y + half_h
      {
        llx: if min_x < bbox.llx { min_x } else { bbox.llx },
        lly: if min_y < bbox.lly { min_y } else { bbox.lly },
        urx: if max_x > bbox.urx { max_x } else { bbox.urx },
        ury: if max_y > bbox.ury { max_y } else { bbox.ury },
      }
    }
    _ => bbox
  }
}

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
  // Graphviz parity: addLabelBB applies GD_flip for LR/RL, so swap label
  // dimensions in pre-rotation space to match compute_bb.
  let rankdir = graph_rankdir(graph)
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  let adjust_metrics = (metrics : EdgeLabelMetrics?) => {
    match metrics {
      Some(value) => {
        let extent : LabelExtent =
          if flip {
            { width: value.height, height: value.width }
          } else {
            { width: value.width, height: value.height }
          }
        Some(extent)
      }
      None => None
    }
  }
  let mut bbox = layout.bbox
  for edge_layout in layout.edges {
    let edge = edge_layout.edge
    let tail = edge.tail().name()
    let head = edge.head().name()
    let is_flat =
      match (ranks.get(tail), ranks.get(head)) {
        (Some(tail_rank), Some(head_rank)) => tail_rank == head_rank
        _ => false
      }
    let has_flat_label_vnode =
      match flat_label_edge_vnodes.get(@dot_shared.edge_key(edge)) {
        Some(_) => true
        None => false
      }
    // Graphviz parity: adjacent flat-edge labels do not update BB
    // (dotsplines.c makeSimpleFlatLabels has no updateBB call).
    // Graphviz parity: self-edge labels still update BB via dotsplines.
    let skip_mid_label = is_flat && !has_flat_label_vnode && tail != head
    bbox = expand_bbox_for_label_pos(
      bbox,
      if skip_mid_label { None } else { edge_layout.label_pos },
      if skip_mid_label {
        None
      } else {
        adjust_metrics(edge_mid_label_metrics(edge))
      },
    )
    if !flip && is_flat && has_flat_label_vnode && tail != head {
      match edge_layout.label_pos {
        Some(center) => {
          let orientation = record_layout_orientation(rankdir)
          let tail_size = node_size(edge.tail(), orientation)
          let head_size = node_size(edge.head(), orientation)
          let tail_half = tail_size.height_pt / 2.0
          let head_half = head_size.height_pt / 2.0
          let half_height = if tail_half > head_half { tail_half } else { head_half }
          let top = center.y + half_height
          if top > bbox.ury {
            bbox = { llx: bbox.llx, lly: bbox.lly, urx: bbox.urx, ury: top }
          }
        }
        None => ()
      }
    }
    bbox = expand_bbox_for_label_pos(
      bbox,
      edge_layout.head_label_pos,
      adjust_metrics(
        edge_label_metrics_for_attr(
          edge_layout.edge,
          "headlabel",
          true,
        ),
      ),
    )
    bbox = expand_bbox_for_label_pos(
      bbox,
      edge_layout.tail_label_pos,
      adjust_metrics(
        edge_label_metrics_for_attr(
          edge_layout.edge,
          "taillabel",
          true,
        ),
      ),
    )
  }
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
