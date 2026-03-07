///|
/// Shared internal dot-package type aliases.
type LayoutPrep = @dot_shared.LayoutPrep

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

///|
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
        @dot_shared.parse_first_double(value, 0.0),
      )
    None => ()
  }
  match graph.get_attr("ranksep") {
    Some(value) =>
      validate_nonnegative_attr(
        "graph",
        "ranksep",
        value,
        @dot_shared.parse_first_double(value, 0.0),
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
          @dot_shared.parse_first_double(value, 0.0),
        )
      None => ()
    }
    match node.get_attr("height") {
      Some(value) =>
        validate_nonnegative_attr(
          "node \{node.name()}",
          "height",
          value,
          @dot_shared.parse_first_double(value, 0.0),
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
          @dot_shared.parse_first_double(value, 0.0),
        )
      None => ()
    }
    match edge.get_attr("weight") {
      Some(value) =>
        validate_nonnegative_attr(
          owner,
          "weight",
          value,
          @dot_shared.parse_first_double(value, 0.0),
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
