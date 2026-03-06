///|
fn build_port_maps_for_nodes(
  nodes : Array[@cgraph.Node],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Map[String, Map[String, RecordPort]] {
  let origin = @geom.Point::{ x: 0.0, y: 0.0 }
  let port_maps : Map[String, Map[String, RecordPort]] = Map::new()
  for node in nodes {
    let label = label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    let has_record = is_record_shape(node)
    if !has_html && !has_record {
      continue
    }
    let name = node.name()
    let size = match sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    let ports =
      if has_html {
      html_ports(node, origin, size)
    } else {
      record_ports(node, origin, size, record_orientation)
    }
    if ports.length() > 0 {
      port_maps[name] = ports
    }
  }
  port_maps
}

///|
fn port_side_mask_for_self_edge(
  node : @cgraph.Node,
  port : @cgraph.Port?,
  port_maps : Map[String, Map[String, RecordPort]],
) -> Int {
  match port {
    None => 0
    Some(value) =>
      match value.compass {
        Some(compass) => compass_side_mask(compass)
        None =>
          match value.name {
            Some(port_name) =>
              match port_maps.get(node.name()) {
                Some(ports) =>
                  match ports.get(port_name) {
                    Some(info) => info.sides
                    None => 0
                  }
                None => 0
              }
            None => 0
          }
      }
  }
}

///|
/// Graphviz parity: self-edge right-side spacing aligned to
/// refs/graphviz/lib/dotgen/position.c (self-edge width padding).
/// Do not change behavior without updating fixtures/tests.
fn apply_self_edge_right_space(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, NodeSize] {
  let port_maps = build_port_maps_for_nodes(nodes, sizes, record_orientation)
  @routing.apply_self_edge_right_space(
    {
      edges,
      sizes,
      rankdir,
      self_edge_size_pt: SELF_EDGE_SIZE_PT,
      self_edge_label_width_for: self_edge_label_width_pt,
      port_side_mask_for:
        (node, port) => port_side_mask_for_self_edge(node, port, port_maps),
    },
  )
}
