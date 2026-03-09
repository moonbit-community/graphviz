///|
/// Graphviz parity: Stage A input preparation owns graph-attribute validation,
/// option canonicalization, and the public prepare entry; geometry assembly
/// continues in input_stage.mbt while the root package keeps API mapping only.
pub(all) struct LayoutInputOptions {
  rankdir : RankDir?
  nodesep : Double?
  ranksep : Double?
  splines : SplinesMode?
}

///|
/// Graphviz parity: default dot nodesep in inches (dotinit/input behavior).
pub const DEFAULT_NODESEP_IN : Double = 0.25

///|
/// Graphviz parity: minimum nodesep/ranksep (MIN_NODESEP/MIN_RANKSEP).
/// Do not change behavior without updating fixtures/tests.
const MIN_NODESEP_IN : Double = 0.02

///|
/// Graphviz parity: default dot ranksep in inches (dotinit/input behavior).
pub const DEFAULT_RANKSEP_IN : Double = 0.5

///|
/// Graphviz parity: minimum nodesep/ranksep (MIN_NODESEP/MIN_RANKSEP).
/// Do not change behavior without updating fixtures/tests.
const MIN_RANKSEP_IN : Double = 0.02

///|
priv struct InputStageInput {
  graph : @cgraph.Graph
  rankdir : RankDir
  nodesep_in : Double
  ranksep_in : Double
  splines : SplinesMode
}

///|
priv struct SpacingResolution {
  nodesep_in : Double
  ranksep_in : Double
}

///|
fn validate_nonnegative_attr(
  owner : String,
  attr_name : String,
  raw_value : String,
  value : Double,
) -> Result[Unit, String] {
  if value < 0.0 {
    Err("\{owner} has negative \{attr_name}: \{raw_value}")
  } else {
    Ok(())
  }
}

///|
fn validate_nonnegative_double_attr(
  owner : String,
  attr_name : String,
  raw_value : String,
) -> Result[Unit, String] {
  validate_nonnegative_attr(
    owner,
    attr_name,
    raw_value,
    @numeric.parse_first_double(raw_value, 0.0),
  )
}

///|
fn validate_graph_spacing(graph : @cgraph.Graph) -> Result[Unit, String] {
  match graph.get_attr("nodesep") {
    Some(value) =>
      match validate_nonnegative_double_attr("graph", "nodesep", value) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    None => ()
  }
  match graph.get_attr("ranksep") {
    Some(value) =>
      match validate_nonnegative_double_attr("graph", "ranksep", value) {
        Ok(_) => ()
        Err(message) => return Err(message)
      }
    None => ()
  }
  Ok(())
}

///|
fn validate_node_dimensions(graph : @cgraph.Graph) -> Result[Unit, String] {
  for node in graph.nodes() {
    match node.get_attr("width") {
      Some(value) =>
        match
          validate_nonnegative_double_attr(
            "node \{node.name()}",
            "width",
            value,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None => ()
    }
    match node.get_attr("height") {
      Some(value) =>
        match
          validate_nonnegative_double_attr(
            "node \{node.name()}",
            "height",
            value,
          ) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None => ()
    }
  }
  Ok(())
}

///|
fn validate_edge_attributes(graph : @cgraph.Graph) -> Result[Unit, String] {
  for edge in graph.edges() {
    let owner = "edge \{edge.tail().name()} -> \{edge.head().name()}"
    match edge.get_attr("minlen") {
      Some(value) =>
        match validate_nonnegative_double_attr(owner, "minlen", value) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None => ()
    }
    match edge.get_attr("weight") {
      Some(value) =>
        match validate_nonnegative_double_attr(owner, "weight", value) {
          Ok(_) => ()
          Err(message) => return Err(message)
        }
      None => ()
    }
  }
  Ok(())
}

///|
/// Graphviz parity: Stage A validates graph spacing and edge/node dimensions
/// before any option resolution, matching the previous root entry sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn validate_layout_graph(graph : @cgraph.Graph) -> Result[Unit, String] {
  match validate_graph_spacing(graph) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  match validate_node_dimensions(graph) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  validate_edge_attributes(graph)
}

///|
pub fn parse_splines(value : String) -> SplinesMode? {
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
fn resolve_rankdir(graph : @cgraph.Graph, option_rankdir : RankDir?) -> RankDir {
  match option_rankdir {
    Some(value) => value
    None =>
      match graph.get_attr("rankdir") {
        Some(value) =>
          match @rankdir.parse_rankdir(value) {
            Some(parsed) => parsed
            None => RankDir::TB
          }
        None => RankDir::TB
      }
  }
}

///|
fn resolve_spacing_scalar(
  graph : @cgraph.Graph,
  option_value : Double?,
  attr_name : String,
  default_value : Double,
  min_value : Double,
) -> Result[Double, String] {
  let raw = match option_value {
    Some(value) => value
    None =>
      match graph.get_attr(attr_name) {
        Some(value) => @numeric.parse_first_double(value, default_value)
        None => default_value
      }
  }
  if raw < 0.0 {
    Err("\{attr_name} must be non-negative")
  } else if raw < min_value {
    Ok(min_value)
  } else {
    Ok(raw)
  }
}

///|
fn resolve_spacing(
  graph : @cgraph.Graph,
  option_nodesep : Double?,
  option_ranksep : Double?,
) -> Result[SpacingResolution, String] {
  let nodesep_in = match
    resolve_spacing_scalar(
      graph,
      option_nodesep,
      "nodesep",
      DEFAULT_NODESEP_IN,
      MIN_NODESEP_IN,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let ranksep_in = match
    resolve_spacing_scalar(
      graph,
      option_ranksep,
      "ranksep",
      DEFAULT_RANKSEP_IN,
      MIN_RANKSEP_IN,
    ) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  Ok({ nodesep_in, ranksep_in })
}

///|
fn resolve_splines(
  graph : @cgraph.Graph,
  option_splines : SplinesMode?,
) -> SplinesMode {
  match option_splines {
    Some(value) => value
    None =>
      match graph.get_attr("splines") {
        Some(value) =>
          match parse_splines(value) {
            Some(parsed) => parsed
            None => SplinesMode::Spline
          }
        None => SplinesMode::Spline
      }
  }
}

///|
/// Graphviz parity: Stage A resolves graph options after validation, then
/// assembles the canonical input snapshot/geometry payload for later stages.
/// Do not change behavior without updating fixtures/tests.
pub fn prepare_layout_prep(
  graph : @cgraph.Graph,
  options : LayoutInputOptions,
) -> Result[LayoutPrep, String] {
  match validate_layout_graph(graph) {
    Ok(_) => ()
    Err(message) => return Err(message)
  }
  let rankdir = resolve_rankdir(graph, options.rankdir)
  let spacing = match resolve_spacing(graph, options.nodesep, options.ranksep) {
    Ok(value) => value
    Err(message) => return Err(message)
  }
  let splines = resolve_splines(graph, options.splines)
  Ok(
    prepare_layout_inputs({
      graph,
      rankdir,
      nodesep_in: spacing.nodesep_in,
      ranksep_in: spacing.ranksep_in,
      splines,
    }),
  )
}
