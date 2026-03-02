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
fn self_edge_extra_right_space(
  edge : @cgraph.Edge,
  rankdir : RankDir,
  port_maps : Map[String, Map[String, RecordPort]],
) -> Double {
  let tail_port = edge.tail_port()
  let head_port = edge.head_port()
  let tail_explicit = @dot_shared.port_is_explicit(tail_port)
  let head_explicit = @dot_shared.port_is_explicit(head_port)
  let label_width = self_edge_label_width_pt(edge, rankdir)
  if !tail_explicit && !head_explicit {
    return SELF_EDGE_SIZE_PT + label_width
  }
  let tail_sides = port_side_mask_for_self_edge(edge.tail(), tail_port, port_maps)
  let head_sides = port_side_mask_for_self_edge(edge.head(), head_port, port_maps)
  let tail_left = (tail_sides & PORT_SIDE_LEFT) != 0
  let head_left = (head_sides & PORT_SIDE_LEFT) != 0
  if !tail_left && !head_left {
    let same_side = tail_sides == head_sides
    let top_bottom = (tail_sides & (PORT_SIDE_TOP | PORT_SIDE_BOTTOM)) != 0
    if !same_side || !top_bottom {
      return SELF_EDGE_SIZE_PT + label_width
    }
  }
  0.0
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
  let mut has_self_edges = false
  for edge in edges {
    if edge.tail().name() == edge.head().name() {
      has_self_edges = true
      break
    }
  }
  if !has_self_edges {
    return sizes
  }
  let port_maps = build_port_maps_for_nodes(nodes, sizes, record_orientation)
  let extra_right : Map[String, Double] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    if tail != edge.head().name() {
      continue
    }
    let extra = self_edge_extra_right_space(edge, rankdir, port_maps)
    if extra <= 0.0 {
      continue
    }
    let current = match extra_right.get(tail) {
      Some(value) => value
      None => 0.0
    }
    extra_right[tail] = current + extra
  }
  if extra_right.length() == 0 {
    return sizes
  }
  let adjusted : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    match extra_right.get(name) {
      Some(extra) => adjusted[name] = size_with_extra_right(size, extra)
      None => adjusted[name] = size
    }
  }
  adjusted
}

///|
fn self_edge_label_half_heights(
  edges : Array[@cgraph.Edge],
) -> Map[String, Double] {
  let heights : Map[String, Double] = Map::new()
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail != head {
      continue
    }
    let half_height = edge_label_height_pt(edge) / 2.0
    let current = match heights.get(tail) {
      Some(value) => value
      None => 0.0
    }
    if half_height > current {
      heights[tail] = half_height
    }
  }
  heights
}

///|
fn node_half_height_pt(
  name : String,
  sizes : Map[String, NodeSize],
  self_edge_labels : Map[String, Double],
) -> Double {
  let base_height = match sizes.get(name) {
    Some(value) => value.height_pt / 2.0
    None => 0.0
  }
  let label_height = match self_edge_labels.get(name) {
    Some(value) => value
    None => 0.0
  }
  if label_height > base_height {
    label_height
  } else {
    base_height
  }
}
