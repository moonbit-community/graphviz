///|
priv struct NodeSize {
  width_in : Double
  height_in : Double
  width_pt : Double
  height_pt : Double
}

///|
fn default_nodesep_in() -> Double {
  0.25
}

///|
fn default_ranksep_in() -> Double {
  0.5
}

///|
fn default_node_width_in() -> Double {
  0.75
}

///|
fn default_node_height_in() -> Double {
  0.5
}

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @strconv.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}

///|
fn parse_first_double(value : String, fallback : Double) -> Double {
  let sb = StringBuilder::new()
  let mut seen = false
  for ch in value {
    if ch.is_ascii_digit() || ch == '-' || ch == '+' || ch == '.' {
      sb.write_char(ch)
      seen = true
    } else if seen {
      break
    }
  }
  if !seen {
    fallback
  } else {
    parse_double(sb.to_string(), fallback)
  }
}

///|
fn parse_rankdir(value : String) -> RankDir? {
  match value.to_lower() {
    "tb" => Some(RankDir::TB)
    "bt" => Some(RankDir::BT)
    "lr" => Some(RankDir::LR)
    "rl" => Some(RankDir::RL)
    _ => None
  }
}

///|
fn parse_splines(value : String) -> SplinesMode? {
  match value.to_lower() {
    "true" | "spline" | "splines" => Some(SplinesMode::Spline)
    "false" | "none" | "" => Some(SplinesMode::None)
    "polyline" => Some(SplinesMode::Polyline)
    "ortho" => Some(SplinesMode::Ortho)
    "curved" => Some(SplinesMode::Curved)
    _ => None
  }
}

///|
fn node_size(node : @cgraph.Node) -> NodeSize {
  let width_in = match node.get_attr("width") {
    Some(value) => parse_double(value, default_node_width_in())
    None => default_node_width_in()
  }
  let height_in = match node.get_attr("height") {
    Some(value) => parse_double(value, default_node_height_in())
    None => default_node_height_in()
  }
  {
    width_in,
    height_in,
    width_pt: width_in * 72.0,
    height_pt: height_in * 72.0,
  }
}

///|
fn clip_to_rect(
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
) -> @geom.Point {
  let dx = target.x - center.x
  let dy = target.y - center.y
  if dx == 0.0 && dy == 0.0 {
    return center
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  let tx = if dx == 0.0 { 1000000000.0 } else { half_w / Double::abs(dx) }
  let ty = if dy == 0.0 { 1000000000.0 } else { half_h / Double::abs(dy) }
  let t = if tx < ty { tx } else { ty }
  { x: center.x + dx * t, y: center.y + dy * t }
}

///|
fn ordered_nodes(graph : @cgraph.Graph) -> Array[@cgraph.Node] {
  graph.nodes()
}

///|
fn compute_ranks_directed(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
) -> Map[String, Int] {
  let indegree : Map[String, Int] = Map::new()
  let outgoing : Map[String, Array[String]] = Map::new()
  let names : Array[String] = []
  for node in nodes {
    let name = node.name()
    indegree[name] = 0
    outgoing[name] = []
    names.push(name)
  }
  for edge in edges {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let count = match indegree.get(head) {
      Some(value) => value
      None => 0
    }
    indegree[head] = count + 1
    match outgoing.get(tail) {
      Some(list) => list.push(head)
      None => outgoing[tail] = [head]
    }
  }
  let queue : Array[String] = []
  for name in names {
    let count = match indegree.get(name) {
      Some(value) => value
      None => 0
    }
    if count == 0 {
      queue.push(name)
    }
  }
  let ranks : Map[String, Int] = Map::new()
  let max_parent : Map[String, Int] = Map::new()
  let mut index = 0
  while index < queue.length() {
    let name = queue[index]
    index = index + 1
    let rank = match max_parent.get(name) {
      Some(value) => value
      None => 0
    }
    ranks[name] = rank
    match outgoing.get(name) {
      Some(list) => {
        for head in list {
          let remaining = match indegree.get(head) {
            Some(value) => value - 1
            None => 0
          }
          indegree[head] = remaining
          let candidate = rank + 1
          let current = match max_parent.get(head) {
            Some(value) => value
            None => 0
          }
          if candidate > current {
            max_parent[head] = candidate
          }
          if remaining == 0 {
            queue.push(head)
          }
        }
      }
      None => ()
    }
  }
  for name in names {
    if ranks.get(name) is None {
      ranks[name] = 0
    }
  }
  ranks
}

///|
fn build_rank_groups(
  nodes : Array[@cgraph.Node],
  ranks : Map[String, Int],
) -> Map[Int, Array[String]] {
  let groups : Map[Int, Array[String]] = Map::new()
  for node in nodes {
    let name = node.name()
    let rank = match ranks.get(name) {
      Some(value) => value
      None => 0
    }
    match groups.get(rank) {
      Some(list) => list.push(name)
      None => groups[rank] = [name]
    }
  }
  groups
}

///|
fn format_point(point : @geom.Point) -> String {
  "\{point.x},\{point.y}"
}

///|
fn format_rect(rect : @geom.Rect) -> String {
  "\{rect.llx},\{rect.lly},\{rect.urx},\{rect.ury}"
}

///|
fn port_key(port : @cgraph.Port?) -> String {
  match port {
    None => ""
    Some(value) => {
      let mut out = ""
      match value.name {
        Some(name) => out = name
        None => ()
      }
      match value.compass {
        Some(compass) => {
          let label = match compass {
            @cgraph.Compass::N => "n"
            @cgraph.Compass::NE => "ne"
            @cgraph.Compass::E => "e"
            @cgraph.Compass::SE => "se"
            @cgraph.Compass::S => "s"
            @cgraph.Compass::SW => "sw"
            @cgraph.Compass::W => "w"
            @cgraph.Compass::NW => "nw"
            @cgraph.Compass::C => "c"
          }
          if out == "" {
            out = label
          } else {
            out = "\{out}:\{label}"
          }
        }
        None => ()
      }
      out
    }
  }
}

///|
fn edge_key(edge : @cgraph.Edge) -> String {
  let tail = edge.tail().name()
  let head = edge.head().name()
  let name = match edge.name() {
    Some(value) => value
    None => ""
  }
  let tail_port = port_key(edge.tail_port())
  let head_port = port_key(edge.head_port())
  "\{tail}|\{head}|\{name}|\{tail_port}|\{head_port}"
}

///|
fn compute_bbox(
  nodes : Array[DotLayoutNode],
  edges : Array[DotLayoutEdge],
) -> @geom.Rect {
  let mut bbox_set = false
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut min_y = 0.0
  let mut max_y = 0.0
  for node in nodes {
    let half_w = node.width_in * 72.0 / 2.0
    let half_h = node.height_in * 72.0 / 2.0
    let left = node.pos.x - half_w
    let right = node.pos.x + half_w
    let bottom = node.pos.y - half_h
    let top = node.pos.y + half_h
    if !bbox_set {
      min_x = left
      max_x = right
      min_y = bottom
      max_y = top
      bbox_set = true
    } else {
      if left < min_x {
        min_x = left
      }
      if right > max_x {
        max_x = right
      }
      if bottom < min_y {
        min_y = bottom
      }
      if top > max_y {
        max_y = top
      }
    }
  }
  for edge in edges {
    for spline in edge.splines {
      for point in spline.points {
        if !bbox_set {
          min_x = point.x
          max_x = point.x
          min_y = point.y
          max_y = point.y
          bbox_set = true
        } else {
          if point.x < min_x {
            min_x = point.x
          }
          if point.x > max_x {
            max_x = point.x
          }
          if point.y < min_y {
            min_y = point.y
          }
          if point.y > max_y {
            max_y = point.y
          }
        }
      }
    }
  }
  if bbox_set {
    { llx: min_x, lly: min_y, urx: max_x, ury: max_y }
  } else {
    { llx: 0.0, lly: 0.0, urx: 0.0, ury: 0.0 }
  }
}

///|
fn layout_subgraphs(
  graph : @cgraph.Graph,
  nodes_out : Array[DotLayoutNode],
  edges_out : Array[DotLayoutEdge],
) -> Array[DotLayoutGraph] {
  let result : Array[DotLayoutGraph] = []
  for subgraph in graph.subgraphs() {
    let node_set : Map[String, Bool] = Map::new()
    for node in subgraph.nodes() {
      node_set[node.name()] = true
    }
    let edge_set : Map[String, Bool] = Map::new()
    for edge in subgraph.edges() {
      edge_set[edge_key(edge)] = true
    }
    let sub_nodes : Array[DotLayoutNode] = []
    for node_layout in nodes_out {
      if node_set.get(node_layout.node.name()) is Some(_) {
        sub_nodes.push(node_layout)
      }
    }
    let sub_edges : Array[DotLayoutEdge] = []
    for edge_layout in edges_out {
      if edge_set.get(edge_key(edge_layout.edge)) is Some(_) {
        sub_edges.push(edge_layout)
      }
    }
    let bbox = compute_bbox(sub_nodes, sub_edges)
    let sub_subgraphs = layout_subgraphs(subgraph, nodes_out, edges_out)
    result.push({
      graph: subgraph,
      bbox,
      label_pos: None,
      nodes: sub_nodes,
      edges: sub_edges,
      subgraphs: sub_subgraphs,
    })
  }
  result
}

///|
fn spline_for_edge(tail : @geom.Point, head : @geom.Point) -> @geom.Spline {
  let mid_y = (tail.y + head.y) / 2.0
  let points : Array[@geom.Point] = [
    tail,
    { x: tail.x, y: mid_y },
    { x: head.x, y: mid_y },
    head,
  ]
  { start: Some(tail), end: Some(head), points }
}

///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  {
    rankdir: Some(RankDir::TB),
    nodesep: Some(default_nodesep_in()),
    ranksep: Some(default_ranksep_in()),
    splines: Some(SplinesMode::Spline),
  }
}

///|
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  let rankdir = match opts.rankdir {
    Some(value) => value
    None => match graph.get_attr("rankdir") {
      Some(value) => match parse_rankdir(value) {
        Some(parsed) => parsed
        None => RankDir::TB
      }
      None => RankDir::TB
    }
  }
  if rankdir != RankDir::TB {
    raise DotLayoutError::UnsupportedFeature(message="rankdir not supported yet")
  }
  let nodesep_in = match opts.nodesep {
    Some(value) => value
    None => match graph.get_attr("nodesep") {
      Some(value) => parse_first_double(value, default_nodesep_in())
      None => default_nodesep_in()
    }
  }
  let ranksep_in = match opts.ranksep {
    Some(value) => value
    None => match graph.get_attr("ranksep") {
      Some(value) => parse_first_double(value, default_ranksep_in())
      None => default_ranksep_in()
    }
  }
  let splines = match opts.splines {
    Some(value) => value
    None => match graph.get_attr("splines") {
      Some(value) => match parse_splines(value) {
        Some(parsed) => parsed
        None => SplinesMode::Spline
      }
      None => SplinesMode::Spline
    }
  }
  if splines != SplinesMode::Spline {
    raise DotLayoutError::UnsupportedFeature(
      message="splines mode not supported yet",
    )
  }
  let nodes = ordered_nodes(graph)
  let edges = graph.edges()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    sizes[node.name()] = node_size(node)
  }
  let ranks = if graph.kind() == @cgraph.GraphKind::Directed {
    compute_ranks_directed(nodes, edges)
  } else {
    let base : Map[String, Int] = Map::new()
    for node in nodes {
      base[node.name()] = 0
    }
    base
  }
  let groups = build_rank_groups(nodes, ranks)
  let rank_keys : Array[Int] = []
  for key, _ in groups {
    rank_keys.push(key)
  }
  rank_keys.sort()
  let rank_heights : Map[Int, Double] = Map::new()
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let mut max_height = 0.0
    for name in names {
      let size = match sizes.get(name) {
        Some(value) => value
        None => node_size(graph.node(name))
      }
      if size.height_pt > max_height {
        max_height = size.height_pt
      }
    }
    rank_heights[rank] = max_height
  }
  let positions : Map[String, @geom.Point] = Map::new()
  let nodesep_pt = nodesep_in * 72.0
  let ranksep_pt = ranksep_in * 72.0
  let mut total_height = 0.0
  for i in 0..<rank_keys.length() {
    let rank = rank_keys[i]
    let height = match rank_heights.get(rank) {
      Some(value) => value
      None => 0.0
    }
    total_height = total_height + height
    if i + 1 < rank_keys.length() {
      total_height = total_height + ranksep_pt
    }
  }
  let mut current_y = total_height
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    let max_height = match rank_heights.get(rank) {
      Some(value) => value
      None => 0.0
    }
    let mut current_x = 0.0
    for name in names {
      let size = match sizes.get(name) {
        Some(value) => value
        None => node_size(graph.node(name))
      }
      let pos_x = current_x + size.width_pt / 2.0
      let pos_y = current_y - max_height / 2.0
      positions[name] = { x: pos_x, y: pos_y }
      current_x = current_x + size.width_pt + nodesep_pt
    }
    current_y = current_y - max_height - ranksep_pt
  }
  let nodes_out : Array[DotLayoutNode] = []
  for node in nodes {
    let name = node.name()
    let pos = match positions.get(name) {
      Some(value) => value
      None => { x: 0.0, y: 0.0 }
    }
    let size = match sizes.get(name) {
      Some(value) => value
      None => node_size(node)
    }
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
    })
  }
  let edges_out : Array[DotLayoutEdge] = []
  for edge in edges {
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
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
      None => node_size(edge.tail())
    }
    let head_size = match sizes.get(head_name) {
      Some(value) => value
      None => node_size(edge.head())
    }
    let tail_clip = clip_to_rect(tail_pos, tail_size, head_pos)
    let head_clip = clip_to_rect(head_pos, head_size, tail_pos)
    let spline = spline_for_edge(tail_clip, head_clip)
    let label_pos : @geom.Point? = match edge.get_attr("label") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some({ x: (tail_clip.x + head_clip.x) / 2.0, y: (tail_clip.y + head_clip.y) / 2.0 })
        }
      }
      None => None
    }
    let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some(head_clip)
        }
      }
      None => None
    }
    let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
      Some(value) => {
        if value == "" {
          None
        } else {
          Some(tail_clip)
        }
      }
      None => None
    }
    edges_out.push({
      edge,
      splines: [spline],
      label_pos,
      head_label_pos,
      tail_label_pos,
    })
  }
  let bbox = compute_bbox(nodes_out, edges_out)
  {
    graph,
    bbox,
    label_pos: None,
    nodes: nodes_out,
    edges: edges_out,
    subgraphs: layout_subgraphs(graph, nodes_out, edges_out),
  }
}

///|
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  self.graph.set_attr("bb", format_rect(self.bbox))
  for node_layout in self.nodes {
    let node = node_layout.node
    node.set_attr("pos", format_point(node_layout.pos))
    node.set_attr("width", node_layout.width_in.to_string())
    node.set_attr("height", node_layout.height_in.to_string())
    match node_layout.label_pos {
      Some(pos) => node.set_attr("lp", format_point(pos))
      None => ()
    }
  }
  for edge_layout in self.edges {
    let edge = edge_layout.edge
    let segments : Array[String] = []
    for spline in edge_layout.splines {
      let parts : Array[String] = []
      match spline.start {
        Some(point) => parts.push("s,\{format_point(point)}")
        None => ()
      }
      match spline.end {
        Some(point) => parts.push("e,\{format_point(point)}")
        None => ()
      }
      for point in spline.points {
        parts.push(format_point(point))
      }
      segments.push(parts.join(" "))
    }
    let pos = segments.join(";")
    edge.set_attr("pos", pos)
    match edge_layout.label_pos {
      Some(pos) => edge.set_attr("lp", format_point(pos))
      None => ()
    }
    match edge_layout.head_label_pos {
      Some(pos) => edge.set_attr("head_lp", format_point(pos))
      None => ()
    }
    match edge_layout.tail_label_pos {
      Some(pos) => edge.set_attr("tail_lp", format_point(pos))
      None => ()
    }
  }
  for subgraph in self.subgraphs {
    subgraph.apply()
  }
}
