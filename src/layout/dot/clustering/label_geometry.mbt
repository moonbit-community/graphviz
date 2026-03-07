///|
/// Cluster-label geometry helpers shared by rank-height, x-position, and final
/// cluster bbox adjustment paths.
type RankDir = @rankdir.RankDir

///|
pub const CLUSTER_LABEL_PAD_PT : Double = 8.0

///|
pub fn cluster_label_padding_for_layout(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> ClusterLabelPadding {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    return { top: 0.0, bottom: 0.0 }
  }
  match @shared.graph_label_metrics_with(graph, @label_metrics.label_text_dimensions) {
    Some(metrics) => {
      let pad = CLUSTER_LABEL_PAD_PT
      match @shared.graph_label_loc(graph) {
        @shared.LabelLoc::Top => { top: metrics.height_pt + pad, bottom: 0.0 }
        @shared.LabelLoc::Bottom => { top: 0.0, bottom: metrics.height_pt + pad }
      }
    }
    None => { top: 0.0, bottom: 0.0 }
  }
}

///|
pub fn cluster_label_width_with_pad_for_layout(graph : @cgraph.Graph) -> Double? {
  match @shared.graph_label_metrics_with(graph, @label_metrics.label_text_dimensions) {
    Some(metrics) => Some(metrics.width_pt + CLUSTER_LABEL_PAD_PT * 2.0)
    None => None
  }
}

///|
pub fn cluster_label_borders_for_xpos_constraints(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> (Double, Double) {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if !flip {
    return (0.0, 0.0)
  }
  match @shared.graph_label_metrics_with(graph, @label_metrics.label_text_dimensions) {
    Some(metrics) => {
      let border = metrics.height_pt + CLUSTER_LABEL_PAD_PT
      match @shared.graph_label_loc(graph) {
        @shared.LabelLoc::Top => (0.0, border)
        @shared.LabelLoc::Bottom => (border, 0.0)
      }
    }
    None => (0.0, 0.0)
  }
}

///|
pub fn expand_cluster_label_bbox_for_position_stage(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
) -> @geom.Rect {
  match @shared.graph_label_metrics_with(graph, @label_metrics.label_text_dimensions) {
    Some(metrics) =>
      @shared.expand_bbox_for_label(
        bbox,
        metrics.width_pt,
        metrics.height_pt,
        @shared.graph_label_loc(graph),
      )
    None => bbox
  }
}
