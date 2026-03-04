///|
/// Stage E edge metrics and tuning helpers for routed-edge solve.

///|
/// Graphviz parity: label edge counts aligned to refs/graphviz/lib/dotgen/dotsplines.c (label spacing).
/// Do not change behavior without updating fixtures/tests.
fn build_label_edge_counts(
  edges : Array[@cgraph.Edge],
) -> Map[String, Int] {
  let label_edge_counts : Map[String, Int] = Map::new()
  for edge in edges {
    if edge_mid_label_text(edge) is Some(_) {
      let tail = edge.tail().name()
      let current = match label_edge_counts.get(tail) {
        Some(value) => value
        None => 0
      }
      label_edge_counts[tail] = current + 1
    }
  }
  label_edge_counts
}

///|
/// Graphviz parity: complex tuning toggle mirrors fixture gating for dotsplines heuristics.
/// Do not change behavior without updating fixtures/tests.
fn complex_tuning_enabled() -> Bool {
  match @sys.get_env_var("DOT_COMPLEX_TUNING") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => false
  }
}

///|
/// Graphviz parity: port padding aligned to refs/graphviz/lib/dotgen/position.c (sameport/compound spacing).
/// Do not change behavior without updating fixtures/tests.
priv struct PortPadding {
  port_pad_below : Double
  port_pad_above : Double
}

///|
/// Graphviz parity: port padding aligned to refs/graphviz/lib/dotgen/position.c (sameport/compound spacing).
/// Do not change behavior without updating fixtures/tests.
fn compute_port_padding(
  has_clusters : Bool,
  has_port_edges : Bool,
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> PortPadding {
  if has_clusters || !has_port_edges {
    { port_pad_below: 0.0, port_pad_above: 0.0 }
  } else {
    let port_padding =
      record_port_padding_y(edges, positions, label_ports_map)
    { port_pad_below: port_padding.below, port_pad_above: port_padding.above }
  }
}

///|
/// Graphviz parity: head port metrics aligned to refs/graphviz/lib/dotgen/dotsplines.c (curve offsets).
/// Do not change behavior without updating fixtures/tests.
fn collect_head_port_metrics(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  label_ports_map : Map[String, Map[String, RecordPort]],
  record_orientation : RecordOrientation,
  enable_complex_tuning : Bool,
) -> @routing.HeadPortMetrics {
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if enable_complex_tuning {
    for edge in edges {
      let tail_name = edge.tail().name()
      let head_name = edge.head().name()
      let head_port = @dot_shared.port_key(edge.head_port())
      let key =
        if head_port == "" {
        if is_record_shape(edge.head()) { head_name } else { "" }
      } else {
        "\{head_name}:\{head_port}"
      }
      if key == "" {
        continue
      }
      let tail_pos = match positions.get(tail_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let head_pos = match positions.get(head_name) {
        Some(value) => value
        None => { x: 0.0, y: 0.0 }
      }
      let tail_size = match sizes.get(tail_name) {
        Some(value) => value
        None => node_size(edge.tail(), record_orientation)
      }
      let head_size = match sizes.get(head_name) {
        Some(value) => value
        None => node_size(edge.head(), record_orientation)
      }
      let tail_geometry = port_geometry(
        tail_name,
        edge.tail_port(),
        label_ports_map,
        tail_pos,
        tail_size,
      )
      let head_geometry = port_geometry(
        head_name,
        edge.head_port(),
        label_ports_map,
        head_pos,
        head_size,
      )
      let dx = head_geometry.center.x - tail_geometry.center.x
      let dy = head_geometry.center.y - tail_geometry.center.y
      let dist = Double::sqrt(dx * dx + dy * dy)
      let current = match head_port_counts.get(key) {
        Some(value) => value
        None => 0
      }
      head_port_counts[key] = current + 1
      let mut min_dist = match head_port_min_dist.get(key) {
        Some(value) => value
        None => dist
      }
      let mut max_dist = match head_port_max_dist.get(key) {
        Some(value) => value
        None => dist
      }
      if dist < min_dist {
        min_dist = dist
      }
      if dist > max_dist {
        max_dist = dist
      }
      head_port_min_dist[key] = min_dist
      head_port_max_dist[key] = max_dist
    }
  }
  { head_port_counts, head_port_min_dist, head_port_max_dist }
}

