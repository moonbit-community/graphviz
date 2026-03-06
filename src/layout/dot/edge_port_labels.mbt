///|
/// Port-label parameter parsing and placement helpers for edge endpoints.

///|
priv struct PortLabelParams {
  angle_deg : Double
  distance_scale : Double
}

///|
fn port_label_params(edge : @cgraph.Edge) -> PortLabelParams? {
  let angle_attr = edge.get_attr("labelangle")
  let distance_attr = edge.get_attr("labeldistance")
  let has_angle = match angle_attr {
    Some(value) => value != ""
    None => false
  }
  let has_distance = match distance_attr {
    Some(value) => value != ""
    None => false
  }
  if !has_angle && !has_distance {
    return None
  }
  let angle_deg = match angle_attr {
    Some(value) =>
      if value == "" {
        PORT_LABEL_ANGLE_DEG
      } else {
        @dot_shared.parse_attr_double(
          value,
          PORT_LABEL_ANGLE_DEG,
          PORT_LABEL_ANGLE_MIN_DEG,
        )
      }
    None => PORT_LABEL_ANGLE_DEG
  }
  let distance_scale = match distance_attr {
    Some(value) =>
      if value == "" {
        1.0
      } else {
        @dot_shared.parse_attr_double(value, 1.0, 0.0)
      }
    None => 1.0
  }
  Some({ angle_deg, distance_scale })
}

fn port_label_points(
  spline : @geom.Spline,
  head_p : Bool,
  marker_present : Bool,
) -> PointWithTangent? {
  // Graphviz parity: place_portlabel uses eflag/sflag to choose marker tangent
  // (marker present => use marker+endpoint tangent, absent => use Bezier sample).
  let points = spline.points
  if points.length() < 4 {
    return None
  }
  if head_p {
    match spline.end {
      Some(end_point) =>
        if marker_present {
          Some({ pos: end_point, tangent: points[points.length() - 1] })
        } else {
          let start = points.length() - 4
          let p0 = points[start]
          let p1 = points[start + 1]
          let p2 = points[start + 2]
          let p3 = points[start + 3]
          Some({ pos: p3, tangent: bezier_point_fma(p0, p1, p2, p3, 0.9) })
        }
      None => {
        let start = points.length() - 4
        let p0 = points[start]
        let p1 = points[start + 1]
        let p2 = points[start + 2]
        let p3 = points[start + 3]
        Some({ pos: p3, tangent: bezier_point_fma(p0, p1, p2, p3, 0.9) })
      }
    }
  } else {
    match spline.start {
      Some(start_point) =>
        if marker_present {
          Some({ pos: start_point, tangent: points[0] })
        } else {
          let p0 = points[0]
          let p1 = points[1]
          let p2 = points[2]
          let p3 = points[3]
          Some({ pos: p0, tangent: bezier_point_fma(p0, p1, p2, p3, 0.1) })
        }
      None => {
        let p0 = points[0]
        let p1 = points[1]
        let p2 = points[2]
        let p3 = points[3]
        Some({ pos: p0, tangent: bezier_point_fma(p0, p1, p2, p3, 0.1) })
      }
    }
  }
}

///|
fn port_label_pos_from_points(
  pe : @geom.Point,
  pf : @geom.Point,
  angle_deg : Double,
  distance_scale : Double,
) -> @geom.Point {
  let angle =
    @edge_spline.libm_fma(
      angle_deg / 180.0,
      GRAPHVIZ_PI,
      @edge_spline.libm_atan2(pf.y - pe.y, pf.x - pe.x),
    )
  let dist = PORT_LABEL_DISTANCE_PT * distance_scale
  @edge_spline.point(
    @edge_spline.libm_fma(dist, @edge_spline.libm_cos(angle), pe.x),
    @edge_spline.libm_fma(dist, @edge_spline.libm_sin(angle), pe.y),
  )
}

///|
fn edge_port_label_pos(
  input : @routing.EdgePortLabelPosInput,
) -> @geom.Point? {
  let edge = input.edge
  let spline = input.spline
  let head_p = input.is_head
  // Graphviz parity: map edge dir + arrow attrs to place_portlabel eflag/sflag.
  let graph_kind = edge.tail().graph().kind()
  let marker_present =
    if head_p {
      @dot_shared.edge_has_head_marker(edge, graph_kind)
    } else {
      @dot_shared.edge_has_tail_marker(edge, graph_kind)
    }
  match port_label_params(edge) {
    Some(params) =>
      match port_label_points(spline, head_p, marker_present) {
        Some(port_points) =>
          Some(
            port_label_pos_from_points(
              port_points.pos,
              port_points.tangent,
              params.angle_deg,
              params.distance_scale,
            ),
          )
        None => None
      }
    None => None
  }
}
