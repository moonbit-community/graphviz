fn scale_point_value(point : @geom.Point, sx : Double, sy : Double) -> @geom.Point {
  { x: point.x * sx, y: point.y * sy }
}

///|
fn scale_point_value_rounded(
  point : @geom.Point,
  sx : Double,
  sy : Double,
) -> @geom.Point {
  let scaled = scale_point_value(point, sx, sy)
  { x: scaled.x.round(), y: scaled.y.round() }
}

///|
fn scale_optional_point_value(
  point : @geom.Point?,
  sx : Double,
  sy : Double,
) -> @geom.Point? {
  match point {
    Some(value) => Some(scale_point_value(value, sx, sy))
    None => None
  }
}

///|
fn scale_spline_value(
  spline : @geom.Spline,
  sx : Double,
  sy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(scale_point_value(point, sx, sy))
  }
  {
    start: scale_optional_point_value(spline.start, sx, sy),
    end: scale_optional_point_value(spline.end, sx, sy),
    points,
  }
}

///|
fn scale_edge_layout_output(
  edges : Array[DotLayoutEdge],
  sx : Double,
  sy : Double,
) -> Array[DotLayoutEdge] {
  let scaled : Array[DotLayoutEdge] = []
  for edge_layout in edges {
    let splines : Array[@geom.Spline] = []
    for spline in edge_layout.splines {
      splines.push(scale_spline_value(spline, sx, sy))
    }
    scaled.push({
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
  scaled
}

///|
fn scale_point_map_rounded(
  points : Map[String, @geom.Point],
  sx : Double,
  sy : Double,
) -> Map[String, @geom.Point] {
  let scaled : Map[String, @geom.Point] = Map::new()
  for name, point in points {
    scaled[name] = scale_point_value_rounded(point, sx, sy)
  }
  scaled
}

///|
fn scale_node_size_value(
  size : NodeSize,
  sx : Double,
  sy : Double,
) -> NodeSize {
  let width_pt = size.width_pt * sx
  let height_pt = size.height_pt * sy
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: size.left_pt * sx,
    right_pt: size.right_pt * sx,
  }
}

///|
priv struct RatioFillScaleFactors {
  sx : Double
  sy : Double
}

///|
/// Graphviz parity: ratio=fill scaling aligned to refs/graphviz/lib/dotgen/position.c
/// (set_aspect R_FILL branch).
fn ratio_fill_scale_factors(
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
  let target_size = match @dot_shared.parse_graph_size_pt_attr(graph) {
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

fn scale_double_map_rounded(
  values : Map[Int, Double],
  scale : Double,
) -> Map[Int, Double] {
  let scaled : Map[Int, Double] = Map::new()
  for key, value in values {
    scaled[key] = (value * scale).round()
  }
  scaled
}

///|
fn scale_named_double_map(
  values : Map[String, Double],
  scale : Double,
) -> Map[String, Double] {
  let scaled : Map[String, Double] = Map::new()
  for key, value in values {
    scaled[key] = value * scale
  }
  scaled
}

///|
fn scale_rect_map(
  rects : Map[String, @geom.Rect],
  sx : Double,
  sy : Double,
) -> Map[String, @geom.Rect] {
  let scaled : Map[String, @geom.Rect] = Map::new()
  for key, rect in rects {
    scaled[key] = {
      llx: rect.llx * sx,
      lly: rect.lly * sy,
      urx: rect.urx * sx,
      ury: rect.ury * sy,
    }
  }
  scaled
}

///|
fn scale_record_port_maps(
  maps : Map[String, Map[String, RecordPort]],
  sx : Double,
  sy : Double,
) -> Map[String, Map[String, RecordPort]] {
  let scaled : Map[String, Map[String, RecordPort]] = Map::new()
  for node_name, ports in maps {
    let scaled_ports : Map[String, RecordPort] = Map::new()
    for port_name, port in ports {
      scaled_ports[port_name] = {
        center: scale_point_value(port.center, sx, sy),
        size: scale_node_size_value(port.size, sx, sy),
        sides: port.sides,
      }
    }
    scaled[node_name] = scaled_ports
  }
  scaled
}
