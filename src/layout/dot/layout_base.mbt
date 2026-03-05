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
const CL_BACK : Int = 10
const CL_CROSS : Int = 1000
const VNODE_HEIGHT_PT : Double = 1.0

///|
fn default_point_size_in() -> Double {
  0.05
}

///|
fn parse_double(value : String, fallback : Double) -> Double {
  @dot_shared.parse_double_or(value, fallback)
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
const MAX_XPOS_VNODES : Int = 100000

///|
const MAX_XPOS_REORDER_VNODES : Int = 5000
