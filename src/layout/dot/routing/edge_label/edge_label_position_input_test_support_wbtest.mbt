///|
fn make_edge_label_pos_input(
  edge : @cgraph.Edge,
  spline : @geom.Spline,
  rankdir : @rankdir.RankDir,
  label_rank_y? : Double? = None,
  label_rank_x? : Double? = None,
  apply_label_pad? : Bool = false,
  nodesep_pt? : Double = 10.0,
  label_pad_boost? : Double = 0.0,
  tail_clip? : @geom.Point = @edge_spline.point(0.0, 0.0),
  head_clip? : @geom.Point = @edge_spline.point(9.0, 0.0),
) -> EdgeLabelPosInput {
  {
    edge,
    spline,
    tail_clip,
    head_clip,
    rankdir,
    label_rank_y,
    label_rank_x,
    apply_label_pad,
    nodesep_pt,
    label_pad_boost,
  }
}
