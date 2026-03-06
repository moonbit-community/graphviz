///|
/// Graphviz parity: routing-stage ratio rescale helpers keep edge geometry and
/// map snapshots synchronized when stage-e runs pre-route ratio=fill scaling.

///|
fn scale_spline_value(
  spline : @geom.Spline,
  sx : Double,
  sy : Double,
) -> @geom.Spline {
  let points : Array[@geom.Point] = []
  for point in spline.points {
    points.push(@dot_shared.scale_point(point, sx, sy))
  }
  {
    start: @dot_shared.scale_optional_point(spline.start, sx, sy),
    end: @dot_shared.scale_optional_point(spline.end, sx, sy),
    points,
  }
}

///|
pub fn scale_edge_layout_output(
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
      label_pos: @dot_shared.scale_optional_point(edge_layout.label_pos, sx, sy),
      head_label_pos: @dot_shared.scale_optional_point(
        edge_layout.head_label_pos,
        sx,
        sy,
      ),
      tail_label_pos: @dot_shared.scale_optional_point(
        edge_layout.tail_label_pos,
        sx,
        sy,
      ),
      xlabel_pos: @dot_shared.scale_optional_point(edge_layout.xlabel_pos, sx, sy),
    })
  }
  scaled
}

///|
pub fn scale_point_map_rounded(
  points : Map[String, @geom.Point],
  sx : Double,
  sy : Double,
) -> Map[String, @geom.Point] {
  let scaled : Map[String, @geom.Point] = Map::new()
  for name, point in points {
    scaled[name] = @dot_shared.scale_point_rounded(point, sx, sy)
  }
  scaled
}

///|
fn scale_node_size_value(
  size : @dot_shared.NodeSize,
  sx : Double,
  sy : Double,
) -> @dot_shared.NodeSize {
  @dot_shared.node_size_from_points(size.width_pt * sx, size.height_pt * sy)
}

///|
pub fn scale_double_map_rounded(
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
pub fn scale_named_double_map(
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
pub fn scale_rect_map(
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
pub fn scale_record_port_maps(
  maps : Map[String, Map[String, @dot_shared.RecordPort]],
  sx : Double,
  sy : Double,
) -> Map[String, Map[String, @dot_shared.RecordPort]] {
  let scaled : Map[String, Map[String, @dot_shared.RecordPort]] = Map::new()
  for node_name, ports in maps {
    let scaled_ports : Map[String, @dot_shared.RecordPort] = Map::new()
    for port_name, port in ports {
      scaled_ports[port_name] = {
        center: @dot_shared.scale_point(port.center, sx, sy),
        size: scale_node_size_value(port.size, sx, sy),
        sides: port.sides,
      }
    }
    scaled[node_name] = scaled_ports
  }
  scaled
}
