///|
/// Shared geometry scaling helpers used by routing and final postprocess ratio
/// paths.

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
  let target_size = match @numeric.parse_graph_size_pt_attr(graph) {
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

///|
pub fn scale_point(
  point : @geom.Point,
  sx : Double,
  sy : Double,
) -> @geom.Point {
  { x: point.x * sx, y: point.y * sy }
}

///|
pub fn scale_point_rounded(
  point : @geom.Point,
  sx : Double,
  sy : Double,
) -> @geom.Point {
  let scaled = scale_point(point, sx, sy)
  { x: scaled.x.round(), y: scaled.y.round() }
}

///|
pub fn scale_optional_point(
  point : @geom.Point?,
  sx : Double,
  sy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(scale_point(value, sx, sy))
    None => None
  }
}
