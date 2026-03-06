///|
/// Cluster-label padding/width helpers shared by positioning and finalization.

///|
fn cluster_label_padding_for_layout(
  graph : @cgraph.Graph,
  rankdir : RankDir,
) -> @clustering.ClusterLabelPadding {
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    return { top: 0.0, bottom: 0.0 }
  }
  match graph_label_metrics(graph) {
    Some(metrics) => {
      let loc = @dot_shared.graph_label_loc(graph)
      let pad = CLUSTER_LABEL_PAD_PT
      match loc {
        LabelLoc::Top => { top: metrics.height_pt + pad, bottom: 0.0 }
        LabelLoc::Bottom => { top: 0.0, bottom: metrics.height_pt + pad }
      }
    }
    None => { top: 0.0, bottom: 0.0 }
  }
}

///|
fn cluster_label_width_with_pad_for_layout(graph : @cgraph.Graph) -> Double? {
  match graph_label_metrics(graph) {
    Some(metrics) => Some(metrics.width_pt + CLUSTER_LABEL_PAD_PT * 2.0)
    None => None
  }
}
