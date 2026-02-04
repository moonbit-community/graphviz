///|
fn try_parse_double(text : String) -> Double? {
  try @strconv.parse_double(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_numbers(text : String, limit : Int) -> Array[Double] {
  let numbers : Array[Double] = []
  let mut current = StringBuilder::new()
  let mut seen = false
  for ch in text {
    if ch.is_ascii_digit() ||
      ch == '-' ||
      ch == '+' ||
      ch == '.' ||
      ch == 'e' ||
      ch == 'E' {
      current.write_char(ch)
      seen = true
      continue
    }
    if seen {
      match try_parse_double(current.to_string()) {
        Some(value) => numbers.push(value)
        None => ()
      }
      if numbers.length() >= limit {
        return numbers
      }
      current = StringBuilder::new()
      seen = false
    }
  }
  if seen {
    match try_parse_double(current.to_string()) {
      Some(value) => numbers.push(value)
      None => ()
    }
  }
  numbers
}

///|
fn parse_point_attr(text : String) -> @geom.Point? {
  let numbers = parse_numbers(text, 2)
  if numbers.length() < 2 {
    None
  } else {
    Some({ x: numbers[0], y: numbers[1] })
  }
}

///|
fn scale_point(point : @geom.Point, factor : Double) -> @geom.Point {
  { x: point.x * factor, y: point.y * factor }
}

///|
fn line_control_points(
  start : @geom.Point,
  end : @geom.Point,
) -> Array[@geom.Point] {
  let control1 : @geom.Point = {
    x: (start.x * 2.0 + end.x) / 3.0,
    y: (start.y * 2.0 + end.y) / 3.0,
  }
  let control2 : @geom.Point = {
    x: (start.x + end.x * 2.0) / 3.0,
    y: (start.y + end.y * 2.0) / 3.0,
  }
  [start, control1, control2, end]
}

///|
fn line_spline(
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> @geom.Spline {
  let start = clip_to_rect(tail_pos, tail_size, head_pos)
  let end = clip_to_rect(head_pos, head_size, tail_pos)
  {
    start: Some(start),
    end: Some(end),
    points: line_control_points(start, end),
  }
}

///|
fn parse_edge_token(token : String) -> (String?, @geom.Point?) {
  if token == "" {
    return (None, None)
  }
  if token.has_prefix("s,") {
    let rest = token.unsafe_substring(start=2, end=token.length())
    return (Some("s"), parse_point_attr(rest))
  }
  if token.has_prefix("e,") {
    let rest = token.unsafe_substring(start=2, end=token.length())
    return (Some("e"), parse_point_attr(rest))
  }
  (None, parse_point_attr(token))
}

///|
fn normalize_spline_points(points : Array[@geom.Point]) -> Array[@geom.Point] {
  if points.length() >= 4 && (points.length() - 1) % 3 == 0 {
    points
  } else if points.length() >= 2 {
    line_control_points(points[0], points[points.length() - 1])
  } else {
    []
  }
}

///|
fn parse_edge_pos(value : String, scale_factor : Double) -> Array[@geom.Spline] {
  let splines : Array[@geom.Spline] = []
  for segment in value.split(";") {
    let mut start : @geom.Point? = None
    let mut end : @geom.Point? = None
    let points : Array[@geom.Point] = []
    for token in segment.split(" ") {
      let (tag, point) = parse_edge_token(token.to_string())
      match point {
        Some(value) => {
          let scaled = scale_point(value, scale_factor)
          match tag {
            Some("s") => start = Some(scaled)
            Some("e") => end = Some(scaled)
            None => points.push(scaled)
            _ => ()
          }
        }
        None => ()
      }
    }
    let normalized = normalize_spline_points(points)
    if normalized.length() > 0 {
      splines.push({ start, end, points: normalized })
    }
  }
  splines
}

///|
fn prune_keep_set(graph : @cgraph.Graph) -> Map[String, Bool] {
  let nodes = graph.nodes()
  let degree : Map[String, Int] = Map::new()
  let neighbors : Map[String, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    degree[name] = 0
    neighbors[name] = []
  }
  for edge in graph.edges() {
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      let current = match degree.get(tail) {
        Some(value) => value
        None => 0
      }
      degree[tail] = current + 2
      continue
    }
    let tail_degree = match degree.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_degree = match degree.get(head) {
      Some(value) => value
      None => 0
    }
    degree[tail] = tail_degree + 1
    degree[head] = head_degree + 1
    match neighbors.get(tail) {
      Some(list) => list.push(head)
      None => neighbors[tail] = [head]
    }
    match neighbors.get(head) {
      Some(list) => list.push(tail)
      None => neighbors[head] = [tail]
    }
  }
  let removed : Map[String, Bool] = Map::new()
  let queue : Array[String] = []
  for name, deg in degree {
    if deg <= 1 {
      queue.push(name)
    }
  }
  let mut index = 0
  while index < queue.length() {
    let name = queue[index]
    index = index + 1
    if removed.get(name) is Some(_) {
      continue
    }
    removed[name] = true
    match neighbors.get(name) {
      Some(list) =>
        for neighbor in list {
          if removed.get(neighbor) is Some(_) {
            continue
          }
          let current = match degree.get(neighbor) {
            Some(value) => value
            None => 0
          }
          let next = current - 1
          degree[neighbor] = next
          if next <= 1 {
            queue.push(neighbor)
          }
        }
      None => ()
    }
  }
  let keep : Map[String, Bool] = Map::new()
  for node in nodes {
    let name = node.name()
    if removed.get(name) is None {
      keep[name] = true
    }
  }
  keep
}

///|
fn clone_pruned_graph(
  graph : @cgraph.Graph,
  keep : Map[String, Bool],
) -> @cgraph.Graph {
  let cloned = match graph.name() {
    Some(name) =>
      @cgraph.Graph::new(graph.kind(), name~, strict=graph.is_strict())
    None => @cgraph.Graph::new(graph.kind(), strict=graph.is_strict())
  }
  for pair in graph.attrs() {
    let (key, value) = pair
    cloned.set_attr(key, value)
  }
  for pair in graph.default_attrs(@cgraph.AttrKind::Graph) {
    let (key, value) = pair
    cloned.set_default_attr(@cgraph.AttrKind::Graph, key, value)
  }
  for pair in graph.default_attrs(@cgraph.AttrKind::Node) {
    let (key, value) = pair
    cloned.set_default_attr(@cgraph.AttrKind::Node, key, value)
  }
  for pair in graph.default_attrs(@cgraph.AttrKind::Edge) {
    let (key, value) = pair
    cloned.set_default_attr(@cgraph.AttrKind::Edge, key, value)
  }
  for node in graph.nodes() {
    let name = node.name()
    if keep.get(name) is None {
      continue
    }
    let new_node = cloned.node(name)
    for pair in node.attrs() {
      let (key, value) = pair
      new_node.set_attr(key, value)
    }
  }
  for edge in graph.edges() {
    let tail = edge.tail()
    let head = edge.head()
    let tail_name = tail.name()
    let head_name = head.name()
    if keep.get(tail_name) is None || keep.get(head_name) is None {
      continue
    }
    let new_tail = cloned.node(tail_name)
    let new_head = cloned.node(head_name)
    let name = edge.name()
    let tail_port = edge.tail_port()
    let head_port = edge.head_port()
    let new_edge = match name {
      Some(label) =>
        match tail_port {
          Some(tail_value) =>
            match head_port {
              Some(head_value) =>
                cloned.edge(
                  new_tail,
                  new_head,
                  name=label,
                  tail_port=tail_value,
                  head_port=head_value,
                )
              None =>
                cloned.edge(
                  new_tail,
                  new_head,
                  name=label,
                  tail_port=tail_value,
                )
            }
          None =>
            match head_port {
              Some(head_value) =>
                cloned.edge(
                  new_tail,
                  new_head,
                  name=label,
                  head_port=head_value,
                )
              None => cloned.edge(new_tail, new_head, name=label)
            }
        }
      None =>
        match tail_port {
          Some(tail_value) =>
            match head_port {
              Some(head_value) =>
                cloned.edge(
                  new_tail,
                  new_head,
                  tail_port=tail_value,
                  head_port=head_value,
                )
              None => cloned.edge(new_tail, new_head, tail_port=tail_value)
            }
          None =>
            match head_port {
              Some(head_value) =>
                cloned.edge(new_tail, new_head, head_port=head_value)
              None => cloned.edge(new_tail, new_head)
            }
        }
    }
    for pair in edge.attrs() {
      let (key, value) = pair
      new_edge.set_attr(key, value)
    }
  }
  cloned
}

///|
pub fn layout_neato_noop(
  graph : @cgraph.Graph,
  no_op_level? : Int = 1,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  let active_graph = if prune {
    let keep = prune_keep_set(graph)
    clone_pruned_graph(graph, keep)
  } else {
    graph
  }
  reset_label_caches()
  let scale_value = if scale <= 0.0 { 72.0 } else { scale }
  let scale_factor = 72.0 / scale_value
  let record_orientation =
    record_layout_orientation(graph_rankdir(active_graph))
  let positions : Map[String, @geom.Point] = Map::new()
  let nodes_out : Array[DotLayoutNode] = []
  for node in ordered_nodes(active_graph) {
    let pos_value = match node.get_attr("pos") {
      Some(value) => value
      None =>
        raise DotLayoutError::InvalidGraph(
          message="neato -n requires pos for node \{node.name()}",
        )
    }
    let parsed = match parse_point_attr(pos_value) {
      Some(value) => value
      None =>
        raise DotLayoutError::InvalidGraph(
          message="invalid pos for node \{node.name()}",
        )
    }
    let pos = scale_point(parsed, scale_factor)
    positions[node.name()] = pos
    let size = node_size(node, record_orientation)
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    })
  }
  let use_edge_pos = no_op_level > 1
  let edges_out : Array[DotLayoutEdge] = []
  for edge in active_graph.edges() {
    let tail = edge.tail()
    let head = edge.head()
    let tail_name = tail.name()
    let head_name = head.name()
    let tail_pos = match positions.get(tail_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let head_pos = match positions.get(head_name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let tail_size = node_size(tail, record_orientation)
    let head_size = node_size(head, record_orientation)
    let splines = if use_edge_pos {
      match edge.get_attr("pos") {
        Some(value) => {
          let parsed = parse_edge_pos(value, scale_factor)
          if parsed.length() > 0 {
            parsed
          } else {
            [line_spline(tail_pos, head_pos, tail_size, head_size)]
          }
        }
        None => [line_spline(tail_pos, head_pos, tail_size, head_size)]
      }
    } else {
      [line_spline(tail_pos, head_pos, tail_size, head_size)]
    }
    edges_out.push({
      edge,
      splines,
      label_pos: None,
      head_label_pos: None,
      tail_label_pos: None,
      xlabel_pos: None,
    })
  }
  let base_bbox = compute_bbox(nodes_out, edges_out)
  let empty_cluster_ln_x : Map[String, Double] = Map::new()
  let empty_cluster_rn_x : Map[String, Double] = Map::new()
  let subgraphs =
    layout_subgraphs(
      active_graph,
      nodes_out,
      edges_out,
      empty_cluster_ln_x,
      empty_cluster_rn_x,
    )
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

///|
pub fn layout_dot_noop(
  graph : @cgraph.Graph,
  no_op_level? : Int = 1,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  layout_neato_noop(
    graph,
    no_op_level=no_op_level,
    scale=scale,
    prune=prune,
  )
}
