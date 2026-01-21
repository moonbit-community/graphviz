///|
fn is_pin_value(value : String) -> Bool {
  match value.to_lower() {
    "true" | "yes" | "1" => true
    _ => false
  }
}

///|
fn pos_is_pinned(value : String) -> Bool {
  if value == "" {
    return false
  }
  let last = value[value.length() - 1]
  last == '!'
}

///|
fn pinned_pos(node : @cgraph.Node) -> @geom.Point? {
  let pin = match node.get_attr("pin") {
    Some(value) => is_pin_value(value)
    None => false
  }
  match node.get_attr("pos") {
    Some(value) => {
      if pin || pos_is_pinned(value) {
        parse_point_attr(value)
      } else {
        None
      }
    }
    None => None
  }
}

///|
fn neato_nodesep_pt(graph : @cgraph.Graph) -> Double {
  let nodesep_in = match graph.get_attr("nodesep") {
    Some(value) => parse_double(value, default_nodesep_in())
    None => default_nodesep_in()
  }
  nodesep_in * 72.0
}

///|
pub fn layout_neato(
  graph : @cgraph.Graph,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  let active_graph = if prune {
    let keep = prune_keep_set(graph)
    clone_pruned_graph(graph, keep)
  } else {
    graph
  }
  let scale_value = if scale <= 0.0 { 72.0 } else { scale }
  let scale_factor = 72.0 / scale_value
  let nodes = ordered_nodes(active_graph)
  let node_count = nodes.length()
  let sizes : Map[String, NodeSize] = Map::new()
  let mut max_half = 0.0
  for node in nodes {
    let size = node_size(node)
    sizes[node.name()] = size
    let half = if size.width_pt > size.height_pt {
      size.width_pt / 2.0
    } else {
      size.height_pt / 2.0
    }
    if half > max_half {
      max_half = half
    }
  }
  let nodesep_pt = neato_nodesep_pt(active_graph)
  let spacing = max_half * 2.0 + nodesep_pt
  let mut radius = if node_count > 1 {
    spacing * node_count.to_double() / (2.0 * @math.PI)
  } else {
    0.0
  }
  if node_count > 1 && radius < spacing {
    radius = spacing
  }
  let positions : Map[String, @geom.Point] = Map::new()
  let nodes_out : Array[DotLayoutNode] = []
  for i in 0..<node_count {
    let node = nodes[i]
    let angle = if node_count > 0 {
      2.0 * @math.PI * i.to_double() / node_count.to_double()
    } else {
      0.0
    }
    let base_pos : @geom.Point = {
      x: radius * @math.cos(angle),
      y: radius * @math.sin(angle),
    }
    let pos = match pinned_pos(node) {
      Some(value) => value
      None => base_pos
    }
    let scaled = scale_point(pos, scale_factor)
    positions[node.name()] = scaled
    let size = match sizes.get(node.name()) {
      Some(value) => value
      None => node_size(node)
    }
    nodes_out.push({
      node,
      pos: scaled,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
    })
  }
  let edges_out : Array[DotLayoutEdge] = []
  for edge in active_graph.edges() {
    let tail = edge.tail()
    let head = edge.head()
    let tail_pos = match positions.get(tail.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let head_pos = match positions.get(head.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let tail_size = match sizes.get(tail.name()) {
      Some(value) => value
      None => node_size(tail)
    }
    let head_size = match sizes.get(head.name()) {
      Some(value) => value
      None => node_size(head)
    }
    edges_out.push({
      edge,
      splines: [line_spline(tail_pos, head_pos, tail_size, head_size)],
      label_pos: None,
      head_label_pos: None,
      tail_label_pos: None,
    })
  }
  let base_bbox = compute_bbox(nodes_out, edges_out)
  let subgraphs = layout_subgraphs(active_graph, nodes_out, edges_out)
  let mut final_bbox = if subgraphs.length() > 0 {
    expand_bbox_with_subgraphs(base_bbox, subgraphs)
  } else {
    base_bbox
  }
  let mut label_pos : @geom.Point? = None
  if active_graph.is_root() {
    match graph_label_metrics(active_graph) {
      Some((width_pt, height_pt)) => {
        let loc = graph_label_loc(active_graph)
        let just = graph_label_just(active_graph)
        final_bbox = expand_bbox_for_label(final_bbox, width_pt, height_pt, loc)
        label_pos = Some(graph_label_pos(final_bbox, width_pt, height_pt, loc, just))
      }
      None => ()
    }
  }
  {
    graph: active_graph,
    bbox: final_bbox,
    label_pos,
    nodes: nodes_out,
    edges: edges_out,
    subgraphs,
  }
}
