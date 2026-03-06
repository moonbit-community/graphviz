///|
/// Shared helpers for noop/neato engine entry paths.

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
    degree[tail] = tail_degree + 1
    let head_degree = match degree.get(head) {
      Some(value) => value
      None => 0
    }
    degree[head] = head_degree + 1
    let tail_neighbors = match neighbors.get(tail) {
      Some(value) => value
      None => []
    }
    tail_neighbors.push(head)
    neighbors[tail] = tail_neighbors
    let head_neighbors = match neighbors.get(head) {
      Some(value) => value
      None => []
    }
    head_neighbors.push(tail)
    neighbors[head] = head_neighbors
  }
  let removed : Map[String, Bool] = Map::new()
  let queue : Array[String] = []
  for node in nodes {
    let name = node.name()
    let node_degree = match degree.get(name) {
      Some(value) => value
      None => 0
    }
    if node_degree <= 1 {
      queue.push(name)
    }
  }
  while queue.length() > 0 {
    let name = queue[queue.length() - 1]
    ignore(queue.pop())
    if removed.get(name) is Some(_) {
      continue
    }
    removed[name] = true
    let adjacent = match neighbors.get(name) {
      Some(value) => value
      None => []
    }
    for next in adjacent {
      if removed.get(next) is Some(_) {
        continue
      }
      let node_degree = match degree.get(next) {
        Some(value) => value
        None => 0
      }
      let reduced = node_degree - 1
      degree[next] = reduced
      if reduced <= 1 {
        queue.push(next)
      }
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
fn active_graph_for_prune(
  graph : @cgraph.Graph,
  prune : Bool,
) -> @cgraph.Graph {
  if prune {
    let keep = prune_keep_set(graph)
    clone_pruned_graph(graph, keep)
  } else {
    graph
  }
}

///|
/// Shared point parsing/scaling and straight-line spline helpers used by
/// noop/neato layout entry paths.

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
  let start = @dot_shared.clip_to_rect(tail_pos, tail_size, head_pos)
  let end = @dot_shared.clip_to_rect(head_pos, head_size, tail_pos)
  {
    start: Some(start),
    end: Some(end),
    points: line_control_points(start, end),
  }
}

///|
/// Graphviz parity: noop/neato output assembly mirrors dot postprocess shape:
/// cluster subgraph recursion + bbox expansion + root label placement.
fn finalize_unranked_layout_graph(
  graph : @cgraph.Graph,
  rankdir : RankDir,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
) -> DotLayoutGraph {
  let base_bbox = compute_bbox(nodes_out, edges_out)
  let empty_cluster_ln_x : Map[String, Double] = Map::new()
  let empty_cluster_rn_x : Map[String, Double] = Map::new()
  let empty_cluster_bbox_heights : Map[String, ClusterBboxHeightPair] = Map::new()
  let empty_ranks : Map[String, Int] = Map::new()
  let empty_rank_y : Map[Int, Double] = Map::new()
  let empty_rank_ht1 : Map[Int, Double] = Map::new()
  let empty_rank_ht2 : Map[Int, Double] = Map::new()
  let subgraphs =
    layout_subgraphs(
      {
        graph,
        nodes_out,
        edges_out,
        cluster_ln_x: empty_cluster_ln_x,
        cluster_rn_x: empty_cluster_rn_x,
        cluster_bbox_heights: empty_cluster_bbox_heights,
        rankdir,
        ranks: empty_ranks,
        rank_y: empty_rank_y,
        rank_ht1: empty_rank_ht1,
        rank_ht2: empty_rank_ht2,
      },
    )
  let mut final_bbox = if subgraphs.length() > 0 {
    expand_bbox_with_subgraphs(base_bbox, subgraphs)
  } else {
    base_bbox
  }
  let mut label_pos : @geom.Point? = None
  if graph.is_root() {
    match graph_label_metrics(graph) {
      Some(metrics) => {
        let loc = graph_label_loc(graph)
        let just = graph_label_just(graph)
        final_bbox =
          expand_bbox_for_label(
            final_bbox,
            metrics.width_pt,
            metrics.height_pt,
            loc,
          )
        label_pos = Some(
          graph_label_pos(
            final_bbox,
            metrics.width_pt,
            metrics.height_pt,
            loc,
            just,
          ),
        )
      }
      None => ()
    }
  }
  {
    graph,
    bbox: final_bbox,
    label_pos,
    nodes: nodes_out,
    edges: edges_out,
    subgraphs,
  }
}
