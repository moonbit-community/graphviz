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
fn node_pos_hint(node : @cgraph.Node) -> (@geom.Point?, Bool) {
  let pin_attr = match node.get_attr("pin") {
    Some(value) => is_pin_value(value)
    None => false
  }
  match node.get_attr("pos") {
    Some(value) =>
      match parse_point_attr(value) {
        Some(pos) => {
          let pinned = pin_attr || pos_is_pinned(value)
          (Some(pos), pinned)
        }
        None => (None, false)
      }
    None => (None, false)
  }
}

///|
priv struct NeatoEdge {
  tail : Int
  head : Int
  length_pt : Double
  weight : Double
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
fn relax_positions(
  positions : Array[@geom.Point],
  pinned : Array[Bool],
  radii : Array[Double],
  edges : Array[NeatoEdge],
  spacing : Double,
  nodesep_pt : Double,
  iterations : Int,
) -> Unit {
  let node_count = positions.length()
  if node_count <= 1 {
    return ()
  }
  let mut pinned_count = 0
  for value in pinned {
    if value {
      pinned_count = pinned_count + 1
    }
  }
  if pinned_count == node_count {
    return ()
  }
  let mut temperature = spacing * Double::sqrt(node_count.to_double())
  let eps = 0.01
  let mut iter = 0
  while iter < iterations && temperature > 0.01 {
    let disp_x : Array[Double] = []
    let disp_y : Array[Double] = []
    for _ in 0..<node_count {
      disp_x.push(0.0)
      disp_y.push(0.0)
    }
    for i in 0..<node_count {
      let pos_i = positions[i]
      for j in (i + 1)..<node_count {
        let pos_j = positions[j]
        let dx = pos_i.x - pos_j.x
        let dy = pos_i.y - pos_j.y
        let dist = Double::sqrt(dx * dx + dy * dy) + eps
        let min_dist = radii[i] + radii[j] + nodesep_pt
        let mut rep = spacing * spacing / dist
        if dist < min_dist {
          let overlap = min_dist - dist
          rep = rep + overlap * spacing / min_dist
        }
        let fx = dx / dist * rep
        let fy = dy / dist * rep
        disp_x[i] = disp_x[i] + fx
        disp_y[i] = disp_y[i] + fy
        disp_x[j] = disp_x[j] - fx
        disp_y[j] = disp_y[j] - fy
      }
    }
    for edge in edges {
      let u = edge.tail
      let v = edge.head
      let pos_u = positions[u]
      let pos_v = positions[v]
      let dx = pos_u.x - pos_v.x
      let dy = pos_u.y - pos_v.y
      let dist = Double::sqrt(dx * dx + dy * dy) + eps
      let force = (dist - edge.length_pt) * edge.weight
      let fx = dx / dist * force
      let fy = dy / dist * force
      disp_x[u] = disp_x[u] - fx
      disp_y[u] = disp_y[u] - fy
      disp_x[v] = disp_x[v] + fx
      disp_y[v] = disp_y[v] + fy
    }
    for i in 0..<node_count {
      if pinned[i] {
        continue
      }
      let dx = disp_x[i]
      let dy = disp_y[i]
      let disp_len = Double::sqrt(dx * dx + dy * dy)
      if disp_len > 0.0 {
        let step = if disp_len < temperature { disp_len } else { temperature }
        positions[i] = {
          x: positions[i].x + dx / disp_len * step,
          y: positions[i].y + dy / disp_len * step,
        }
      }
    }
    if pinned_count == 0 {
      let mut cx = 0.0
      let mut cy = 0.0
      for pos in positions {
        cx = cx + pos.x
        cy = cy + pos.y
      }
      let inv = 1.0 / node_count.to_double()
      cx = cx * inv
      cy = cy * inv
      for i in 0..<node_count {
        positions[i] = { x: positions[i].x - cx, y: positions[i].y - cy }
      }
    }
    temperature = temperature * 0.9
    iter = iter + 1
  }
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
  let indices : Map[String, Int] = Map::new()
  let radii : Array[Double] = []
  let mut max_half = 0.0
  for i in 0..<node_count {
    let node = nodes[i]
    let size = node_size(node)
    sizes[node.name()] = size
    indices[node.name()] = i
    let half = if size.width_pt > size.height_pt {
      size.width_pt / 2.0
    } else {
      size.height_pt / 2.0
    }
    radii.push(half)
    if half > max_half {
      max_half = half
    }
  }
  let nodesep_pt = neato_nodesep_pt(active_graph)
  let base_spacing = max_half * 2.0 + nodesep_pt
  let spacing = if base_spacing <= 1.0 { 1.0 } else { base_spacing }
  let mut radius = if node_count > 1 {
    spacing * node_count.to_double() / (2.0 * @math.PI)
  } else {
    0.0
  }
  if node_count > 1 && radius < spacing {
    radius = spacing
  }
  let positions : Array[@geom.Point] = []
  let pinned : Array[Bool] = []
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
    let (hint, is_pinned) = node_pos_hint(node)
    let pos = match hint {
      Some(value) => value
      None => base_pos
    }
    positions.push(pos)
    pinned.push(is_pinned)
  }
  let edges : Array[NeatoEdge] = []
  for edge in active_graph.edges() {
    let tail = edge.tail()
    let head = edge.head()
    let tail_index = match indices.get(tail.name()) {
      Some(value) => value
      None => continue
    }
    let head_index = match indices.get(head.name()) {
      Some(value) => value
      None => continue
    }
    if tail_index == head_index {
      continue
    }
    let len_in = match edge.get_attr("len") {
      Some(value) => parse_double(value, 1.0)
      None => 1.0
    }
    let length_in = if len_in <= 0.0 { 1.0 } else { len_in }
    let length_pt = length_in * 72.0
    let raw_weight = match edge.get_attr("weight") {
      Some(value) => parse_double(value, 1.0)
      None => 1.0
    }
    let weight = if raw_weight <= 0.0 { 1.0 } else { raw_weight }
    let min_len = radii[tail_index] + radii[head_index] + nodesep_pt
    let desired = if length_pt > min_len { length_pt } else { min_len }
    edges.push({
      tail: tail_index,
      head: head_index,
      length_pt: desired,
      weight,
    })
  }
  if node_count > 1 {
    relax_positions(positions, pinned, radii, edges, spacing, nodesep_pt, 100)
  }
  let positions_map : Map[String, @geom.Point] = Map::new()
  let nodes_out : Array[DotLayoutNode] = []
  for i in 0..<node_count {
    let node = nodes[i]
    let scaled = scale_point(positions[i], scale_factor)
    positions_map[node.name()] = scaled
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
    let tail_pos = match positions_map.get(tail.name()) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let head_pos = match positions_map.get(head.name()) {
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
        label_pos = Some(
          graph_label_pos(final_bbox, width_pt, height_pt, loc, just),
        )
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
