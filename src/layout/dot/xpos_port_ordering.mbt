///|
/// X-position port ordering and slack minlen helpers.

///|
type SlackSegment = @positioning.SlackSegment

///|
/// Graphviz parity: port order uses compassPort angle quantization
/// (MC_SCALE=256) for mincross medians (shapes.c + mincross.c).
/// Do not change behavior without updating fixtures/tests.
fn port_order_fraction(point : @geom.Point) -> Double {
  if point.x == 0.0 && point.y == 0.0 {
    return 0.5
  }
  let two_pi = 2.0 * @math.PI
  let mut angle = @edge_spline.libm_atan2(point.y, point.x) + 1.5 * @math.PI
  if angle >= two_pi {
    angle = angle - two_pi
  }
  let scaled = (256.0 * angle / two_pi).trunc()
  scaled / 256.0
}

///|
fn record_port_point(
  port_info : RecordPort,
  compass : @cgraph.Compass?,
) -> @geom.Point {
  let center = port_info.center
  let half_w = port_info.size.width_pt / 2.0
  let half_h = port_info.size.height_pt / 2.0
  match compass {
    Some(value) =>
      match value {
        @cgraph.Compass::N => { x: center.x, y: center.y + half_h }
        @cgraph.Compass::NE => { x: center.x + half_w, y: center.y + half_h }
        @cgraph.Compass::E => { x: center.x + half_w, y: center.y }
        @cgraph.Compass::SE => { x: center.x + half_w, y: center.y - half_h }
        @cgraph.Compass::S => { x: center.x, y: center.y - half_h }
        @cgraph.Compass::SW => { x: center.x - half_w, y: center.y - half_h }
        @cgraph.Compass::W => { x: center.x - half_w, y: center.y }
        @cgraph.Compass::NW => { x: center.x - half_w, y: center.y + half_h }
        @cgraph.Compass::C => center
      }
    None => center
  }
}

///|
fn edge_port_order(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  if !@dot_shared.port_is_explicit(port) {
    // Graphviz parity: absent ports contribute neutral 0.0 offset/order.
    return 0.0
  }
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match offsets.get(node_name) {
            Some(node_offsets) =>
              match node_offsets.get(name) {
                Some(port_info) =>
                  port_order_fraction(record_port_point(port_info, value.compass))
                None =>
                  match value.compass {
                    Some(compass) =>
                      port_order_fraction(
                        compass_port_point(
                          node_name,
                          nodes_by_name.get(node_name),
                          compass,
                          sizes,
                          rankdir,
                        ),
                      )
                    None => 0.5
                  }
              }
            None =>
              match value.compass {
                Some(compass) =>
                  port_order_fraction(
                    compass_port_point(
                      node_name,
                      nodes_by_name.get(node_name),
                      compass,
                      sizes,
                      rankdir,
                    ),
                  )
                None => 0.5
              }
          }
        None =>
          match value.compass {
            Some(compass) =>
              port_order_fraction(
                compass_port_point(
                  node_name,
                  nodes_by_name.get(node_name),
                  compass,
                  sizes,
                  rankdir,
                ),
              )
            None => 0.5
          }
      }
    None => 0.5
  }
}

fn segment_slack_minlen(
  segment : SlackSegment,
  port_offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  real_by_name : Map[String, @cgraph.Node],
) -> (Int, Int) {
  let tail_offset = edge_port_offset(
    segment.tail,
    segment.tail_port,
    port_offsets,
    sizes,
    rankdir,
    real_by_name,
  )
  let head_offset = edge_port_offset(
    segment.head,
    segment.head_port,
    port_offsets,
    sizes,
    rankdir,
    real_by_name,
  )
  let delta = head_offset - tail_offset
  let m0 = if delta > 0.0 { @dot_shared.trunc_int(delta) } else { 0 }
  let m1 = if delta < 0.0 { @dot_shared.trunc_int(-delta) } else { 0 }
  (m0, m1)
}
