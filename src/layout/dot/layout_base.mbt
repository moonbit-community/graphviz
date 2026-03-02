///|
fn default_nodesep_in() -> Double {
  0.25
}

///|
/// Graphviz parity: minimum nodesep/ranksep (MIN_NODESEP/MIN_RANKSEP).
/// Do not change behavior without updating fixtures/tests.
const MIN_NODESEP_IN : Double = 0.02

///|
/// Graphviz parity: minimum nodesep/ranksep (MIN_NODESEP/MIN_RANKSEP).
/// Do not change behavior without updating fixtures/tests.
const MIN_RANKSEP_IN : Double = 0.02

///|
fn default_ranksep_in() -> Double {
  0.5
}

///|
const BACKWARD_PENALTY : Int = 1
const CL_BACK : Int = 10
const CL_CROSS : Int = 1000
const VNODE_ENDPOINT_WEIGHT : Int = 1
const DEFAULT_VNODE_WEIGHT : Double = 1.0
const VNODE_HEIGHT_PT : Double = 1.0
const CLUSTER_SKELETON_PREFIX : String = "_mbt_cluster_skel_"

///|
fn default_point_size_in() -> Double {
  0.05
}

///|
fn dot_trace(message : String) -> Unit {
  if @sys.get_env_var("DOT_TRACE") is Some(_) {
    println(message)
  }
}

///|
fn dot_trace_positions(label : String, positions : Map[String, Double]) -> Unit {
  if @sys.get_env_var("DOT_TRACE_POS") is None {
    return ()
  }
  let keys : Array[String] = []
  for name, _ in positions {
    keys.push(name)
  }
  keys.sort()
  for name in keys {
    let value = match positions.get(name) {
      Some(pos) => pos
      None => 0.0
    }
    println("\{label} \{name}: \{value}")
  }
}

///|
fn dot_trace_edges(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_EDGES") is None {
    return ()
  }
  let mut idx = 0
  for edge in edges {
    let tail = if idx < edge_tail.length() { edge_tail[idx] } else {
      edge.tail().name()
    }
    let head = if idx < edge_head.length() { edge_head[idx] } else {
      edge.head().name()
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    println("edge \{idx}: \{tail}(\{tail_rank}) -> \{head}(\{head_rank})")
    idx = idx + 1
  }
}

///|
fn dot_trace_route_points(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
) -> Unit {
  if @sys.get_env_var("DOT_TRACE_ROUTE") is None {
    return ()
  }
  let tail = edge.tail().name()
  let head = edge.head().name()
  let parts : Array[String] = []
  for point in points {
    parts.push("\{point.x},\{point.y}")
  }
  let joined = parts.join(" ")
  println("route \{tail} -> \{head}: \{joined}")
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
priv struct GraphSizePt {
  width_pt : Double
  height_pt : Double
}

///|
/// Graphviz parity: size parsing aligned to refs/graphviz/lib/common/input.c.
fn parse_graph_size_pt_attr(graph : @cgraph.Graph) -> GraphSizePt? {
  match graph.get_attr("size") {
    Some(value) => {
      let parts : Array[String] = []
      for part in value.split(",") {
        let cleaned = part.trim(chars=" \n\r\t!").to_string()
        if cleaned != "" {
          parts.push(cleaned)
        }
      }
      if parts.length() == 0 {
        return None
      }
      let width_in = parse_double(parts[0], -1.0)
      let height_in =
        if parts.length() > 1 {
          parse_double(parts[1], -1.0)
        } else {
          width_in
        }
      if width_in <= 0.0 || height_in <= 0.0 {
        return None
      }
      Some({ width_pt: width_in * 72.0, height_pt: height_in * 72.0 })
    }
    None => None
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
fn parse_first_double_optional(value : String) -> Double? {
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
    None
  } else {
    try @strconv.parse_double(sb.to_string()) catch {
      _ => None
    } noraise {
      parsed => Some(parsed)
    }
  }
}

///|
fn parse_attr_double(value : String, fallback : Double, min : Double) -> Double {
  match parse_first_double_optional(value) {
    Some(parsed) => if parsed < min { min } else { parsed }
    None => fallback
  }
}

///|
fn validate_nonnegative_attr(
  owner : String,
  attr_name : String,
  raw_value : String,
  value : Double,
) -> Unit raise DotLayoutError {
  if value < 0.0 {
    raise DotLayoutError::InvalidGraph(
      message="\{owner} has negative \{attr_name}: \{raw_value}",
    )
  }
}

///|
fn validate_graph_spacing(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  match graph.get_attr("nodesep") {
    Some(value) =>
      validate_nonnegative_attr(
        "graph",
        "nodesep",
        value,
        parse_first_double(value, 0.0),
      )
    None => ()
  }
  match graph.get_attr("ranksep") {
    Some(value) =>
      validate_nonnegative_attr(
        "graph",
        "ranksep",
        value,
        parse_first_double(value, 0.0),
      )
    None => ()
  }
}

///|
fn validate_node_dimensions(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  for node in graph.nodes() {
    match node.get_attr("width") {
      Some(value) =>
        validate_nonnegative_attr(
          "node \{node.name()}",
          "width",
          value,
          parse_first_double(value, 0.0),
        )
      None => ()
    }
    match node.get_attr("height") {
      Some(value) =>
        validate_nonnegative_attr(
          "node \{node.name()}",
          "height",
          value,
          parse_first_double(value, 0.0),
        )
      None => ()
    }
  }
}

///|
fn validate_edge_attributes(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  for edge in graph.edges() {
    let tail = edge.tail().name()
    let head = edge.head().name()
    let owner = "edge \{tail} -> \{head}"
    match edge.get_attr("minlen") {
      Some(value) =>
        validate_nonnegative_attr(
          owner,
          "minlen",
          value,
          parse_first_double(value, 0.0),
        )
      None => ()
    }
    match edge.get_attr("weight") {
      Some(value) =>
        validate_nonnegative_attr(
          owner,
          "weight",
          value,
          parse_first_double(value, 0.0),
        )
      None => ()
    }
  }
}

///|
fn validate_layout_graph(graph : @cgraph.Graph) -> Unit raise DotLayoutError {
  validate_graph_spacing(graph)
  validate_node_dimensions(graph)
  validate_edge_attributes(graph)
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
fn graph_rankdir(graph : @cgraph.Graph) -> RankDir {
  let mut current = graph
  while true {
    match current.get_attr("rankdir") {
      Some(value) =>
        match parse_rankdir(value) {
          Some(parsed) => return parsed
          None => ()
        }
      None => ()
    }
    match current.parent() {
      Some(parent) => current = parent
      None => break
    }
  }
  RankDir::TB
}

///|
fn parse_splines(value : String) -> SplinesMode? {
  match value.to_lower() {
    "true" | "spline" | "splines" => Some(SplinesMode::Spline)
    "false" | "no" | "line" => Some(SplinesMode::Polyline)
    "none" | "" => Some(SplinesMode::None)
    "polyline" => Some(SplinesMode::Polyline)
    "ortho" => Some(SplinesMode::Ortho)
    "curved" => Some(SplinesMode::Curved)
    _ => None
  }
}

///|
priv enum OrderingMode {
  Out
  In
}

///|
fn parse_ordering_mode(value : String) -> OrderingMode? {
  match value.to_lower() {
    "out" => Some(OrderingMode::Out)
    "in" => Some(OrderingMode::In)
    _ => None
  }
}

///|
priv enum EdgeDir {
  Forward
  Back
  Both
  None
}

///|
fn parse_edge_dir(value : String) -> EdgeDir? {
  match value.to_lower() {
    "forward" | "f" => Some(EdgeDir::Forward)
    "back" | "b" => Some(EdgeDir::Back)
    "both" => Some(EdgeDir::Both)
    "none" => Some(EdgeDir::None)
    _ => None
  }
}

///|
fn edge_dir_for(edge : @cgraph.Edge, kind : @cgraph.GraphKind) -> EdgeDir {
  if kind == @cgraph.GraphKind::Undirected {
    return EdgeDir::None
  }
  match edge.get_attr("dir") {
    Some(value) =>
      match parse_edge_dir(value) {
        Some(dir) => dir
        None => EdgeDir::Forward
      }
    None => EdgeDir::Forward
  }
}

///|
const EDGE_VNODE_PREFIX : String = "_mbt_edge_vn_"

///|
const MAX_XPOS_VNODES : Int = 100000

///|
const MAX_XPOS_REORDER_VNODES : Int = 5000

///|
const LARGE_SORT_THRESHOLD : Int = 128
