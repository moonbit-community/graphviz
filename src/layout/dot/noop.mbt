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
fn parse_edge_pos(value : String, scale_factor : Double) -> Array[@geom.Spline] {
  let splines : Array[@geom.Spline] = []
  for segment in value.split(";") {
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
      splines.push({ start, end, points: normalized })
    }
  }
  splines
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
  let scale_value = if scale <= 0.0 { 72.0 } else { scale }
  let scale_factor = 72.0 / scale_value
  let rankdir = @dot_shared.graph_rankdir(active_graph)
  let record_orientation = record_layout_orientation(rankdir)
  let positions : Map[String, @geom.Point] = Map::new()
  let nodes_out : Array[DotLayoutNode] = []
  for node in active_graph.nodes() {
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
  finalize_unranked_layout_graph(active_graph, rankdir, nodes_out, edges_out)
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
