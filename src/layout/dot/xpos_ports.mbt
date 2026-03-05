///|
type SlackSegment = @positioning.SlackSegment

fn port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, NodeSize],
) -> Map[String, Map[String, RecordPort]] {
  let offsets : Map[String, Map[String, RecordPort]] = Map::new()
  let rankdir = if nodes.length() > 0 {
    graph_rankdir(nodes[0].graph())
  } else {
    RankDir::TB
  }
  let record_orientation = record_layout_orientation(rankdir)
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  for node in nodes {
    let name = node.name()
    let base_size = match output_sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    let label = label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    let ports =
      if has_html {
        html_ports(node, origin, base_size)
      } else if is_record_shape(node) {
        record_ports(node, origin, base_size, record_orientation)
      } else {
        Map::new()
      }
    if ports.length() > 0 {
      let node_offsets : Map[String, RecordPort] = Map::new()
      for port_name, port_info in ports {
        let offset = layout_port_offset(port_info.center, rankdir)
        let size = match rankdir {
          RankDir::LR | RankDir::RL => swap_node_size(port_info.size)
          _ => port_info.size
        }
        node_offsets[port_name] = { center: offset, size, sides: port_info.sides }
      }
      offsets[name] = node_offsets
    }
  }
  offsets
}

///|
fn fallback_compass_size() -> NodeSize {
  let width_pt = @dot_shared.default_node_width_in() * 72.0
  let height_pt = @dot_shared.default_node_height_in() * 72.0
  let half = width_pt / 2.0
  {
    width_in: width_pt / 72.0,
    height_in: height_pt / 72.0,
    width_pt,
    height_pt,
    left_pt: half,
    right_pt: half,
  }
}

///|
fn node_size_for_compass(
  node_name : String,
  sizes : Map[String, NodeSize],
) -> NodeSize {
  match sizes.get(node_name) {
    Some(value) => value
    None => fallback_compass_size()
  }
}

///|
fn compass_uses_shape_clipping(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      true
    "diamond"
    | "mdiamond"
    | "triangle"
    | "invtriangle"
    | "trapezium"
    | "invtrapezium"
    | "parallelogram"
    | "egg"
    | "house"
    | "invhouse"
    | "pentagon"
    | "hexagon"
    | "septagon"
    | "octagon"
    | "doubleoctagon"
    | "tripleoctagon" =>
      true
    "polygon" => {
      let attrs = polygon_shape_attrs(node)
      if attrs.sides < 3 {
        true
      } else {
        !polygon_is_box_like(
          attrs.sides,
          attrs.orientation,
          attrs.distortion,
          attrs.skew,
        )
      }
    }
    _ => false
  }
}

fn compass_port_point(
  node_name : String,
  node : @cgraph.Node?,
  compass : @cgraph.Compass,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
) -> @geom.Point {
  let base_size = node_size_for_compass(node_name, sizes)
  let half_height = base_size.height_pt / 2.0
  let left = -base_size.left_pt
  let right = base_size.right_pt
  let top = half_height
  let bottom = -half_height
  let base_point = match compass {
    @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
    _ =>
      match node {
        Some(value) =>
          if compass_uses_shape_clipping(value) {
            @edge_spline.compass_port_point_on_shape(
              value,
              @edge_spline.point(0.0, 0.0),
              base_size,
              compass,
              rankdir,
            )
          } else {
            match compass {
              @cgraph.Compass::N => @geom.Point::{ x: 0.0, y: top }
              @cgraph.Compass::NE => @geom.Point::{ x: right, y: top }
              @cgraph.Compass::E => @geom.Point::{ x: right, y: 0.0 }
              @cgraph.Compass::SE => @geom.Point::{ x: right, y: bottom }
              @cgraph.Compass::S => @geom.Point::{ x: 0.0, y: bottom }
              @cgraph.Compass::SW => @geom.Point::{ x: left, y: bottom }
              @cgraph.Compass::W => @geom.Point::{ x: left, y: 0.0 }
              @cgraph.Compass::NW => @geom.Point::{ x: left, y: top }
              @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
            }
          }
        None =>
          match compass {
            @cgraph.Compass::N => @geom.Point::{ x: 0.0, y: top }
            @cgraph.Compass::NE => @geom.Point::{ x: right, y: top }
            @cgraph.Compass::E => @geom.Point::{ x: right, y: 0.0 }
            @cgraph.Compass::SE => @geom.Point::{ x: right, y: bottom }
            @cgraph.Compass::S => @geom.Point::{ x: 0.0, y: bottom }
            @cgraph.Compass::SW => @geom.Point::{ x: left, y: bottom }
            @cgraph.Compass::W => @geom.Point::{ x: left, y: 0.0 }
            @cgraph.Compass::NW => @geom.Point::{ x: left, y: top }
            @cgraph.Compass::C => @geom.Point::{ x: 0.0, y: 0.0 }
          }
      }
  }
  layout_port_offset(base_point, rankdir)
}

///|
fn compass_port_offset(
  compass : @cgraph.Compass,
  node_name : String,
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  let node = nodes_by_name.get(node_name)
  let unrotated = compass_port_point(node_name, node, compass, sizes, RankDir::TB)
  match node {
    Some(value) =>
      if is_record_shape(value) || @html_label.is_html_label_text(label_text(value)) {
        // Preserve record/html order behavior for explicit label ports.
        unrotated.x
      } else {
        // Graphviz parity: make_edge_pairs consumes compassPort rankdir-rotated
        // ED_{tail,head}_port.p.x for non-record compass-only endpoints.
        layout_port_offset(unrotated, rankdir).x
      }
    None => layout_port_offset(unrotated, rankdir).x
  }
}

///|
fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, RecordPort]],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  nodes_by_name : Map[String, @cgraph.Node],
) -> Double {
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          match offsets.get(node_name) {
            Some(node_offsets) =>
              match node_offsets.get(name) {
                Some(port_info) =>
                  match value.compass {
                    Some(compass) =>
                      match compass {
                        @cgraph.Compass::E
                        | @cgraph.Compass::NE
                        | @cgraph.Compass::SE => {
                          let half = port_info.size.width_pt / 2.0
                          port_info.center.x + half
                        }
                        @cgraph.Compass::W
                        | @cgraph.Compass::NW
                        | @cgraph.Compass::SW => {
                          let half = port_info.size.width_pt / 2.0
                          port_info.center.x - half
                        }
                        _ => port_info.center.x
                      }
                    None => port_info.center.x
                  }
                None =>
                  match value.compass {
                    Some(compass) =>
                      compass_port_offset(
                        compass,
                        node_name,
                        sizes,
                        rankdir,
                        nodes_by_name,
                      )
                    None => 0.0
                  }
              }
            None =>
              match value.compass {
                Some(compass) =>
                  compass_port_offset(
                    compass,
                    node_name,
                    sizes,
                    rankdir,
                    nodes_by_name,
                  )
                None => 0.0
              }
          }
        None =>
          match value.compass {
            Some(compass) =>
              compass_port_offset(
                compass,
                node_name,
                sizes,
                rankdir,
                nodes_by_name,
              )
            None => 0.0
          }
      }
    None => 0.0
  }
}

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
  let m0 = if delta > 0.0 { trunc_int(delta) } else { 0 }
  let m1 = if delta < 0.0 { trunc_int(-delta) } else { 0 }
  (m0, m1)
}

/// Graphviz parity: constraint graph uses GD_nlist order for existing
/// nodes and appends aux slack/cluster nodes per create_aux_edges.
/// Do not change behavior without updating fixtures/tests.
///|
