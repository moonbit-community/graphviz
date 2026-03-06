///|
/// Graphviz parity: ratio=fill scaling aligned to refs/graphviz/lib/dotgen/position.c
/// (set_aspect R_FILL branch).
pub(all) struct RatioFillScaleFactors {
  sx : Double
  sy : Double
}

///|
/// Graphviz parity: ratio=fill scale-factor resolution shared by routing-stage
/// pre-route scaling and final postprocess scaling.
pub fn ratio_fill_scale_factors(
  graph : @cgraph.Graph,
  bbox : @geom.Rect,
  rankdir : RankDir,
) -> RatioFillScaleFactors? {
  let ratio = match graph.get_attr("ratio") {
    Some(value) => value.trim().to_lower()
    None => return None
  }
  if ratio != "fill" {
    return None
  }
  let target_size = match parse_graph_size_pt_attr(graph) {
    Some(size) => size
    None => return None
  }
  let mut span_w = bbox.urx - bbox.llx
  let mut span_h = bbox.ury - bbox.lly
  if span_w <= 0.0 || span_h <= 0.0 {
    return None
  }
  let flip = rankdir == RankDir::LR || rankdir == RankDir::RL
  if flip {
    let tmp = span_w
    span_w = span_h
    span_h = tmp
  }
  let mut xf = target_size.width_pt / span_w
  let mut yf = target_size.height_pt / span_h
  if xf <= 0.0 || yf <= 0.0 {
    return None
  }
  if xf < 1.0 || yf < 1.0 {
    if xf < yf {
      yf = yf / xf
      xf = 1.0
    } else {
      xf = xf / yf
      yf = 1.0
    }
  }
  if flip {
    let tmp = xf
    xf = yf
    yf = tmp
  }
  Some({ sx: xf, sy: yf })
}
