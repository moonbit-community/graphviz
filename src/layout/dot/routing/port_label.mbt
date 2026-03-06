///|
pub fn port_label_params(
  edge : @cgraph.Edge,
  default_angle_deg : Double,
  min_angle_deg : Double,
) -> (Double, Double)? {
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
        default_angle_deg
      } else {
        @dot_shared.parse_attr_double(
          value,
          default_angle_deg,
          min_angle_deg,
        )
      }
    None => default_angle_deg
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
  Some((angle_deg, distance_scale))
}

///|
pub fn port_label_pos_from_points(
  pe : @geom.Point,
  pf : @geom.Point,
  angle_deg : Double,
  distance_scale : Double,
  distance_pt : Double,
  graphviz_pi : Double,
) -> @geom.Point {
  let angle =
    @edge_spline.libm_fma(
      angle_deg / 180.0,
      graphviz_pi,
      @edge_spline.libm_atan2(pf.y - pe.y, pf.x - pe.x),
    )
  let dist = distance_pt * distance_scale
  @edge_spline.point(
    @edge_spline.libm_fma(dist, @edge_spline.libm_cos(angle), pe.x),
    @edge_spline.libm_fma(dist, @edge_spline.libm_sin(angle), pe.y),
  )
}

///|
/// Graphviz parity: port-label placement aligned to refs/graphviz/lib/common/labels.c
/// (place_portlabel), including marker presence and angle/distance attrs.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_port_label_pos(
  input : EdgePortLabelPosInput,
  default_angle_deg : Double,
  min_angle_deg : Double,
  distance_pt : Double,
  graphviz_pi : Double,
) -> @geom.Point? {
  let edge = input.edge
  let spline = input.spline
  let is_head = input.is_head
  // Graphviz parity: map edge dir + arrow attrs to place_portlabel eflag/sflag.
  let graph_kind = edge.tail().graph().kind()
  let marker_present =
    if is_head {
      @dot_shared.edge_has_head_marker(edge, graph_kind)
    } else {
      @dot_shared.edge_has_tail_marker(edge, graph_kind)
    }
  let (angle_deg, distance_scale) =
    match port_label_params(edge, default_angle_deg, min_angle_deg) {
      Some(value) => value
      None => return None
    }
  let port_points = match port_label_points(spline, is_head, marker_present) {
    Some(value) => value
    None => return None
  }
  Some(
    port_label_pos_from_points(
      port_points.pos,
      port_points.tangent,
      angle_deg,
      distance_scale,
      distance_pt,
      graphviz_pi,
    ),
  )
}
