///|
/// Positioning domain: edge-port offset/order sampling core reused by ordering
/// tie-break preprocessing and xpos simplex slack construction.

///|
/// Graphviz parity: edge-port sampling context keeps rankdir lookup, node
/// index, and per-node port offsets fixed before edge endpoint iteration.
/// Do not change behavior without updating fixtures/tests.
pub fn build_port_offsets_for_nodes(
  nodes : Array[@cgraph.Node],
  output_sizes : Map[String, @shared.NodeSize],
  node_size_for_missing : (@cgraph.Node, @shared.RankDir) -> @shared.NodeSize,
  ports_for_node : (@cgraph.Node, @geom.Point, @shared.NodeSize, @shared.RankDir) -> Map[String, @shared.RecordPort],
  layout_port_offset : (@geom.Point, @shared.RankDir) -> @geom.Point,
  swap_node_size : (@shared.NodeSize) -> @shared.NodeSize,
) -> Map[String, Map[String, @shared.RecordPort]] {
  let offsets : Map[String, Map[String, @shared.RecordPort]] = Map::new()
  let rankdir =
    if nodes.length() > 0 {
      @shared.graph_rankdir(nodes[0].graph())
    } else {
      @shared.RankDir::TB
    }
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  for node in nodes {
    let name = node.name()
    let base_size = match output_sizes.get(name) {
      Some(value) => value
      None => node_size_for_missing(node, rankdir)
    }
    let ports = ports_for_node(node, origin, base_size, rankdir)
    if ports.length() > 0 {
      let node_offsets : Map[String, @shared.RecordPort] = Map::new()
      for port_name, port_info in ports {
        let offset = layout_port_offset(port_info.center, rankdir)
        let size = match rankdir {
          @shared.RankDir::LR | @shared.RankDir::RL => swap_node_size(port_info.size)
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
  port_info : @shared.RecordPort,
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
/// Graphviz parity: endpoint port offset follows make_edge_pairs behavior:
/// explicit label ports use record/html map center (+ compass side half-width),
/// missing label ports fall back to compass-only node boundary offsets.
pub fn edge_port_offset(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, @shared.RecordPort]],
  compass_offset_for : (@cgraph.Compass) -> Double,
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
                    Some(compass) => compass_offset_for(compass)
                    None => 0.0
                  }
              }
            None =>
              match value.compass {
                Some(compass) => compass_offset_for(compass)
                None => 0.0
              }
          }
        None =>
          match value.compass {
            Some(compass) => compass_offset_for(compass)
            None => 0.0
          }
      }
    None => 0.0
  }
}

///|
/// Graphviz parity: absent ports contribute neutral 0.0 offset/order, explicit
/// label ports use mapped label-port geometry; compass-only ports quantize
/// boundary angle to 1/256 turn for mincross tie-break parity.
pub fn edge_port_order(
  node_name : String,
  port : @cgraph.Port?,
  offsets : Map[String, Map[String, @shared.RecordPort]],
  compass_point_for : (@cgraph.Compass) -> @geom.Point,
) -> Double {
  if !@shared.port_is_explicit(port) {
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
                    Some(compass) => port_order_fraction(compass_point_for(compass))
                    None => 0.5
                  }
              }
            None =>
              match value.compass {
                Some(compass) => port_order_fraction(compass_point_for(compass))
                None => 0.5
              }
          }
        None =>
          match value.compass {
            Some(compass) => port_order_fraction(compass_point_for(compass))
            None => 0.5
          }
      }
    None => 0.5
  }
}

///|
/// Graphviz parity: shared edge-port sampling setup keeps endpoint remap and
/// per-edge iteration order identical for both x-offset and port-order passes.
/// Do not change behavior without updating fixtures/tests.
pub fn build_edge_port_sample_bundle(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, @shared.NodeSize],
  port_offsets_for_nodes : (Array[@cgraph.Node], Map[String, @shared.NodeSize]) -> Map[String, Map[String, @shared.RecordPort]],
  edge_port_x : (String, @cgraph.Port?, Map[String, Map[String, @shared.RecordPort]], Map[String, @shared.NodeSize], @shared.RankDir, Map[String, @cgraph.Node]) -> Double,
  edge_port_order : (String, @cgraph.Port?, Map[String, Map[String, @shared.RecordPort]], Map[String, @shared.NodeSize], @shared.RankDir, Map[String, @cgraph.Node]) -> Double,
) -> @ordering.EdgePortSampleBundle {
  let rankdir =
    if nodes.length() > 0 {
      @shared.graph_rankdir(nodes[0].graph())
    } else {
      @shared.RankDir::TB
    }
  let nodes_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    nodes_by_name[node.name()] = node
  }
  let port_offsets = port_offsets_for_nodes(nodes, sizes)
  @ordering.build_edge_port_sample_bundle(
    edges,
    edge_tail,
    edge_head,
    (name, port) =>
      edge_port_x(
        name,
        port,
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      ),
    (name, port) =>
      edge_port_order(
        name,
        port,
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      ),
  )
}
