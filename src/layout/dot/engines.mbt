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
fn clone_edge_with_optional_name_ports(
  graph : @cgraph.Graph,
  tail : @cgraph.Node,
  head : @cgraph.Node,
  name : String?,
  tail_port : @cgraph.Port?,
  head_port : @cgraph.Port?,
) -> @cgraph.Edge {
  match name {
    Some(label) =>
      match (tail_port, head_port) {
        (Some(tail_value), Some(head_value)) =>
          graph.edge(
            tail,
            head,
            name=label,
            tail_port=tail_value,
            head_port=head_value,
          )
        (Some(tail_value), None) =>
          graph.edge(
            tail,
            head,
            name=label,
            tail_port=tail_value,
          )
        (None, Some(head_value)) =>
          graph.edge(
            tail,
            head,
            name=label,
            head_port=head_value,
          )
        (None, None) => graph.edge(tail, head, name=label)
      }
    None =>
      match (tail_port, head_port) {
        (Some(tail_value), Some(head_value)) =>
          graph.edge(
            tail,
            head,
            tail_port=tail_value,
            head_port=head_value,
          )
        (Some(tail_value), None) => graph.edge(tail, head, tail_port=tail_value)
        (None, Some(head_value)) => graph.edge(tail, head, head_port=head_value)
        (None, None) => graph.edge(tail, head)
      }
  }
}

///|
fn copy_graph_attrs_and_defaults(
  source : @cgraph.Graph,
  target : @cgraph.Graph,
) -> Unit {
  for pair in source.attrs() {
    let (key, value) = pair
    target.set_attr(key, value)
  }
  for pair in source.default_attrs(@cgraph.AttrKind::Graph) {
    let (key, value) = pair
    target.set_default_attr(@cgraph.AttrKind::Graph, key, value)
  }
  for pair in source.default_attrs(@cgraph.AttrKind::Node) {
    let (key, value) = pair
    target.set_default_attr(@cgraph.AttrKind::Node, key, value)
  }
  for pair in source.default_attrs(@cgraph.AttrKind::Edge) {
    let (key, value) = pair
    target.set_default_attr(@cgraph.AttrKind::Edge, key, value)
  }
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
  copy_graph_attrs_and_defaults(graph, cloned)
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
    let new_edge =
      clone_edge_with_optional_name_ports(
        cloned,
        new_tail,
        new_head,
        edge.name(),
        edge.tail_port(),
        edge.head_port(),
      )
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
fn node_size_with_fallback(
  sizes : Map[String, NodeSize],
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  match sizes.get(node.name()) {
    Some(value) => value
    None => node_size(node, record_orientation)
  }
}

///|
priv struct EngineGeometryContext {
  scale_factor : Double
  rankdir : RankDir
  record_orientation : RecordOrientation
}

///|
fn build_engine_geometry_context(
  graph : @cgraph.Graph,
  scale : Double,
) -> EngineGeometryContext {
  let scale_value = if scale <= 0.0 { 72.0 } else { scale }
  let scale_factor = 72.0 / scale_value
  let rankdir = @dot_shared.graph_rankdir(graph)
  let record_orientation = record_layout_orientation(rankdir)
  { scale_factor, rankdir, record_orientation }
}

///|
fn straight_line_edge_splines(
  _edge : @cgraph.Edge,
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> Array[@geom.Spline] {
  [line_spline(tail_pos, head_pos, tail_size, head_size)]
}

///|
fn build_edges_from_positions(
  graph : @cgraph.Graph,
  positions : Map[String, @geom.Point],
  node_size_for : (@cgraph.Node) -> NodeSize,
  edge_splines_for :
    (@cgraph.Edge, @geom.Point, @geom.Point, NodeSize, NodeSize) -> Array[@geom.Spline],
) -> Array[DotLayoutEdge] {
  let edges_out : Array[DotLayoutEdge] = []
  for edge in graph.edges() {
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
    let tail_size = node_size_for(tail)
    let head_size = node_size_for(head)
    edges_out.push({
      edge,
      splines: edge_splines_for(edge, tail_pos, head_pos, tail_size, head_size),
      label_pos: None,
      head_label_pos: None,
      tail_label_pos: None,
      xlabel_pos: None,
    })
  }
  edges_out
}

///|
priv struct EngineNodeProjection {
  positions : Map[String, @geom.Point]
  nodes_out : Array[DotLayoutNode]
}

///|
priv struct EngineNodeProjectionWithSizes {
  projection : EngineNodeProjection
  sizes : Map[String, NodeSize]
}

///|
fn project_neato_nodes_with_sizes(
  nodes : Array[@cgraph.Node],
  positions : Array[@geom.Point],
  scale_factor : Double,
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
) -> EngineNodeProjectionWithSizes {
  let positions_map : Map[String, @geom.Point] = Map::new()
  let nodes_out : Array[DotLayoutNode] = []
  for i in 0..<nodes.length() {
    let node = nodes[i]
    let scaled = scale_point(positions[i], scale_factor)
    positions_map[node.name()] = scaled
    let size = node_size_with_fallback(sizes, node, record_orientation)
    nodes_out.push({
      node,
      pos: scaled,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    })
  }
  {
    projection: { positions: positions_map, nodes_out },
    sizes,
  }
}

///|
fn collect_noop_nodes_with_sizes(
  graph : @cgraph.Graph,
  scale_factor : Double,
  record_orientation : RecordOrientation,
) -> EngineNodeProjectionWithSizes raise DotLayoutError {
  let positions : Map[String, @geom.Point] = Map::new()
  let nodes_out : Array[DotLayoutNode] = []
  let sizes : Map[String, NodeSize] = Map::new()
  for node in graph.nodes() {
    let pos = parse_required_noop_node_pos(node, scale_factor)
    positions[node.name()] = pos
    let size = node_size(node, record_orientation)
    sizes[node.name()] = size
    nodes_out.push({
      node,
      pos,
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    })
  }
  {
    projection: { positions, nodes_out },
    sizes,
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

priv struct NodePosHint {
  pos : @geom.Point?
  is_pinned : Bool
}

///|
fn node_pos_hint(node : @cgraph.Node) -> NodePosHint {
  let pin_attr = match node.get_attr("pin") {
    Some(value) => is_pin_value(value)
    None => false
  }
  match node.get_attr("pos") {
    Some(value) =>
      match parse_point_attr(value) {
        Some(pos) => {
          let pinned = pin_attr || pos_is_pinned(value)
          { pos: Some(pos), is_pinned: pinned }
        }
        None => { pos: None, is_pinned: false }
      }
    None => { pos: None, is_pinned: false }
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
priv struct NeatoNodeSizing {
  sizes : Map[String, NodeSize]
  indices : Map[String, Int]
  radii : Array[Double]
  max_half : Double
}

///|
fn build_neato_node_sizing(
  nodes : Array[@cgraph.Node],
  record_orientation : RecordOrientation,
) -> NeatoNodeSizing {
  let sizes : Map[String, NodeSize] = Map::new()
  let indices : Map[String, Int] = Map::new()
  let radii : Array[Double] = []
  let mut max_half = 0.0
  for i in 0..<nodes.length() {
    let node = nodes[i]
    let size = node_size(node, record_orientation)
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
  { sizes, indices, radii, max_half }
}

///|
priv struct NeatoInitialNodeState {
  positions : Array[@geom.Point]
  pinned : Array[Bool]
}

///|
fn build_neato_initial_node_state(
  nodes : Array[@cgraph.Node],
  spacing : Double,
) -> NeatoInitialNodeState {
  let node_count = nodes.length()
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
    let hint_data = node_pos_hint(node)
    let pos = match hint_data.pos {
      Some(value) => value
      None => base_pos
    }
    positions.push(pos)
    pinned.push(hint_data.is_pinned)
  }
  { positions, pinned }
}

///|
fn build_neato_edges(
  graph : @cgraph.Graph,
  indices : Map[String, Int],
  radii : Array[Double],
  nodesep_pt : Double,
) -> Array[NeatoEdge] {
  let edges : Array[NeatoEdge] = []
  for edge in graph.edges() {
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
      Some(value) => @dot_shared.parse_double_or(value, 1.0)
      None => 1.0
    }
    let length_in = if len_in <= 0.0 { 1.0 } else { len_in }
    let length_pt = length_in * 72.0
    let raw_weight = match edge.get_attr("weight") {
      Some(value) => @dot_shared.parse_double_or(value, 1.0)
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
  edges
}

///|
fn neato_nodesep_pt(graph : @cgraph.Graph) -> Double {
  let nodesep_in = match graph.get_attr("nodesep") {
    Some(value) => @dot_shared.parse_double_or(value, default_nodesep_in())
    None => default_nodesep_in()
  }
  nodesep_in * 72.0
}

///|
fn validate_neato_edge_lengths(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  for edge in graph.edges() {
    match edge.get_attr("len") {
      Some(value) =>
        validate_nonnegative_attr(
          "edge \{edge.tail().name()} -> \{edge.head().name()}",
          "len",
          value,
          @dot_shared.parse_first_double(value, 0.0),
        )
      None => ()
    }
  }
}

///|
fn zero_double_array(length : Int) -> Array[Double] {
  let values : Array[Double] = []
  for _ in 0..<length {
    values.push(0.0)
  }
  values
}

///|
fn accumulate_repulsive_forces(
  positions : Array[@geom.Point],
  radii : Array[Double],
  spacing : Double,
  nodesep_pt : Double,
  eps : Double,
  disp_x : Array[Double],
  disp_y : Array[Double],
) -> Unit {
  let node_count = positions.length()
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
}

///|
fn accumulate_spring_forces(
  positions : Array[@geom.Point],
  edges : Array[NeatoEdge],
  eps : Double,
  disp_x : Array[Double],
  disp_y : Array[Double],
) -> Unit {
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
}

///|
fn apply_displacements(
  positions : Array[@geom.Point],
  pinned : Array[Bool],
  temperature : Double,
  disp_x : Array[Double],
  disp_y : Array[Double],
) -> Unit {
  for i in 0..<positions.length() {
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
}

///|
fn recenter_positions(positions : Array[@geom.Point]) -> Unit {
  if positions.length() == 0 {
    return ()
  }
  let mut cx = 0.0
  let mut cy = 0.0
  for pos in positions {
    cx = cx + pos.x
    cy = cy + pos.y
  }
  let inv = 1.0 / positions.length().to_double()
  cx = cx * inv
  cy = cy * inv
  for i in 0..<positions.length() {
    positions[i] = { x: positions[i].x - cx, y: positions[i].y - cy }
  }
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
    let disp_x = zero_double_array(node_count)
    let disp_y = zero_double_array(node_count)
    accumulate_repulsive_forces(
      positions,
      radii,
      spacing,
      nodesep_pt,
      eps,
      disp_x,
      disp_y,
    )
    accumulate_spring_forces(positions, edges, eps, disp_x, disp_y)
    apply_displacements(positions, pinned, temperature, disp_x, disp_y)
    if pinned_count == 0 {
      recenter_positions(positions)
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
  let active_graph = active_graph_for_prune(graph, prune)
  validate_layout_graph(active_graph)
  reset_label_caches()
  validate_neato_edge_lengths(active_graph)
  let geometry = build_engine_geometry_context(active_graph, scale)
  let nodes = active_graph.nodes()
  let node_count = nodes.length()
  let sizing = build_neato_node_sizing(nodes, geometry.record_orientation)
  let nodesep_pt = neato_nodesep_pt(active_graph)
  let base_spacing = sizing.max_half * 2.0 + nodesep_pt
  let spacing = if base_spacing <= 1.0 { 1.0 } else { base_spacing }
  let node_state = build_neato_initial_node_state(nodes, spacing)
  let positions = node_state.positions
  let pinned = node_state.pinned
  let edges = build_neato_edges(
    active_graph,
    sizing.indices,
    sizing.radii,
    nodesep_pt,
  )
  if node_count > 1 {
    relax_positions(
      positions,
      pinned,
      sizing.radii,
      edges,
      spacing,
      nodesep_pt,
      100,
    )
  }
  let node_data =
    project_neato_nodes_with_sizes(
      nodes,
      positions,
      geometry.scale_factor,
      sizing.sizes,
      geometry.record_orientation,
    )
  let node_size_for = (node : @cgraph.Node) =>
    node_size_with_fallback(node_data.sizes, node, geometry.record_orientation)
  let edges_out =
    build_edges_from_positions(
      active_graph,
      node_data.projection.positions,
      node_size_for,
      straight_line_edge_splines,
    )
  finalize_unranked_layout_graph(
    active_graph,
    geometry.rankdir,
    node_data.projection.nodes_out,
    edges_out,
  )
}
///|
priv enum EdgeTokenTag {
  Start
  End
}

///|
priv struct EdgeTokenParse {
  tag : EdgeTokenTag?
  point : @geom.Point?
}

///|
fn parse_edge_token(token : String) -> EdgeTokenParse {
  if token == "" {
    return { tag: None, point: None }
  }
  if token.has_prefix("s,") {
    let rest = token.unsafe_substring(start=2, end=token.length())
    return { tag: Some(EdgeTokenTag::Start), point: parse_point_attr(rest) }
  }
  if token.has_prefix("e,") {
    let rest = token.unsafe_substring(start=2, end=token.length())
    return { tag: Some(EdgeTokenTag::End), point: parse_point_attr(rest) }
  }
  { tag: None, point: parse_point_attr(token) }
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
fn parse_edge_pos_segment(
  segment : String,
  scale_factor : Double,
) -> @geom.Spline? {
  let mut start : @geom.Point? = None
  let mut end : @geom.Point? = None
  let points : Array[@geom.Point] = []
  for token in segment.split(" ") {
    let parsed = parse_edge_token(token.to_string())
    match parsed.point {
      Some(value) => {
        let scaled = scale_point(value, scale_factor)
        match parsed.tag {
          Some(EdgeTokenTag::Start) => start = Some(scaled)
          Some(EdgeTokenTag::End) => end = Some(scaled)
          None => points.push(scaled)
        }
      }
      None => ()
    }
  }
  let normalized = normalize_spline_points(points)
  if normalized.length() > 0 {
    Some({ start, end, points: normalized })
  } else {
    None
  }
}

///|
fn parse_edge_pos(value : String, scale_factor : Double) -> Array[@geom.Spline] {
  let splines : Array[@geom.Spline] = []
  for segment in value.split(";") {
    match parse_edge_pos_segment(segment.to_string(), scale_factor) {
      Some(spline) => splines.push(spline)
      None => ()
    }
  }
  splines
}

///|
fn parse_required_noop_node_pos(
  node : @cgraph.Node,
  scale_factor : Double,
) -> @geom.Point raise DotLayoutError {
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
  scale_point(parsed, scale_factor)
}

///|
fn noop_edge_splines(
  edge : @cgraph.Edge,
  use_edge_pos : Bool,
  scale_factor : Double,
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> Array[@geom.Spline] {
  if use_edge_pos {
    match edge.get_attr("pos") {
      Some(value) => {
        let parsed = parse_edge_pos(value, scale_factor)
        if parsed.length() > 0 {
          parsed
        } else {
          straight_line_edge_splines(
            edge,
            tail_pos,
            head_pos,
            tail_size,
            head_size,
          )
        }
      }
      None =>
        straight_line_edge_splines(
          edge,
          tail_pos,
          head_pos,
          tail_size,
          head_size,
        )
    }
  } else {
    straight_line_edge_splines(edge, tail_pos, head_pos, tail_size, head_size)
  }
}

///|
///|
pub fn layout_neato_noop(
  graph : @cgraph.Graph,
  no_op_level? : Int = 1,
  scale? : Double = 72.0,
  prune? : Bool = false,
) -> DotLayoutGraph raise DotLayoutError {
  let active_graph = active_graph_for_prune(graph, prune)
  reset_label_caches()
  let geometry = build_engine_geometry_context(active_graph, scale)
  let node_data =
    collect_noop_nodes_with_sizes(
      active_graph,
      geometry.scale_factor,
      geometry.record_orientation,
    )
  let use_edge_pos = no_op_level > 1
  let node_size_for = (node : @cgraph.Node) =>
    node_size_with_fallback(node_data.sizes, node, geometry.record_orientation)
  let edges_out =
    build_edges_from_positions(
      active_graph,
      node_data.projection.positions,
      node_size_for,
      (edge, tail_pos, head_pos, tail_size, head_size) =>
        noop_edge_splines(
          edge,
          use_edge_pos,
          geometry.scale_factor,
          tail_pos,
          head_pos,
          tail_size,
          head_size,
        ),
    )
  finalize_unranked_layout_graph(
    active_graph,
    geometry.rankdir,
    node_data.projection.nodes_out,
    edges_out,
  )
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
