///|
/// Stage E routing precompute helpers and shared payloads.

///|
priv struct PortLayoutMaps {
  label_ports_map : Map[String, Map[String, RecordPort]]
  label_ports_raw : Map[String, Map[String, RecordPort]]
}

///|
/// Graphviz parity: node layout assembly aligned to refs/graphviz/lib/dotgen/position.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_layout_nodes(
  nodes : Array[@cgraph.Node],
  positions : Map[String, @geom.Point],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> Array[DotLayoutNode] {
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = match output_sizes.get(name) {
      Some(value) => value
      None => node_size(node, record_orientation)
    }
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    })
  }
  nodes_out
}

///|
/// Graphviz parity: port layout maps aligned to refs/graphviz/lib/common/shapes.c (record/html ports).
/// Do not change behavior without updating fixtures/tests.
fn build_port_layout_maps(
  nodes_out : Array[DotLayoutNode],
  output_sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  rankdir : RankDir,
  has_port_edges : Bool,
) -> PortLayoutMaps {
  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  let label_ports_raw : Map[String, Map[String, RecordPort]] = Map::new()
  if has_port_edges {
    for node_layout in nodes_out {
      let name = node_layout.node.name()
      let final_size = match output_sizes.get(name) {
        Some(value) => value
        None => node_size(node_layout.node, record_orientation)
      }
      let label = label_text(node_layout.node)
      let has_html = @html_label.is_html_label_text(label)
      if has_html {
        let raw_ports = html_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      } else if is_record_shape(node_layout.node) {
        let raw_ports = record_ports(
          node_layout.node,
          { x: 0.0, y: 0.0 },
          final_size,
          record_orientation,
        )
        label_ports_raw[name] = raw_ports
        let ports =
          layout_ports_from_final(raw_ports, node_layout.pos, rankdir)
        label_ports_map[name] = ports
      }
    }
  }
  { label_ports_map, label_ports_raw }
}

///|
/// Graphviz parity: cluster routing bboxes aligned to refs/graphviz/lib/dotgen/cluster.c + dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
fn compute_cluster_route_bboxes(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  cluster_ln_x : Map[String, Double],
  cluster_rn_x : Map[String, Double],
  cluster_bbox_heights : Map[String, ClusterBboxHeightPair],
  rankdir : RankDir,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
) -> Map[String, @geom.Rect] {
  let cluster_bboxes : Map[String, @geom.Rect] = Map::new()
  if @dot_shared.graph_has_cluster(graph) {
    let cluster_layouts =
      layout_subgraphs(
        graph,
        nodes_out,
        [],
        cluster_ln_x,
        cluster_rn_x,
        cluster_bbox_heights,
        rankdir,
        ranks,
        rank_y,
        rank_ht1,
        rank_ht2,
      )
    collect_cluster_bboxes(cluster_layouts, cluster_bboxes)
  }
  cluster_bboxes
}

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

