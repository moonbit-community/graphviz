///|
/// Stage A input-stage boundary file: option parsing stays in the root dot
/// package, while snapshot/geometry assembly lives in the input_stage
/// subpackage.

type InputStageDeps = @input_stage.InputStageDeps

///|
/// Graphviz parity: layout attribute parsing aligned to refs/graphviz/lib/dotgen/dotinit.c + lib/common/input.c.
/// Do not change behavior without updating fixtures/tests.
fn prepare_layout_inputs(
  graph : @cgraph.Graph,
  opts : DotLayoutOptions,
) -> LayoutPrep raise DotLayoutError {
  let rankdir = resolve_rankdir(graph, opts.rankdir)
  let spacing =
    resolve_spacing(graph, opts.nodesep, opts.ranksep)
  let splines = resolve_splines(graph, opts.splines)
  @input_stage.prepare_layout_inputs(
    {
      graph,
      rankdir,
      nodesep_in: spacing.nodesep_in,
      ranksep_in: spacing.ranksep_in,
      splines,
    },
    build_input_stage_deps(),
  )
}

///|
priv struct SpacingResolution {
  nodesep_in : Double
  ranksep_in : Double
}

///|
/// Graphviz parity: rankdir resolution uses option override first, then
/// graph attribute parsing with TB fallback (dotinit/input behavior).
/// Do not change behavior without updating fixtures/tests.
fn resolve_rankdir(
  graph : @cgraph.Graph,
  option_rankdir : RankDir?,
) -> RankDir {
  match option_rankdir {
    Some(value) => value
    None =>
      match graph.get_attr("rankdir") {
        Some(value) =>
          match @dot_shared.parse_rankdir(value) {
            Some(parsed) => parsed
            None => RankDir::TB
          }
        None => RankDir::TB
      }
  }
}

///|
/// Graphviz parity: spacing scalar parsing resolves option override first, then
/// graph attribute/default fallback, rejects negatives, and clamps to minimum.
/// Do not change behavior without updating fixtures/tests.
fn resolve_spacing_scalar(
  graph : @cgraph.Graph,
  option_value : Double?,
  attr_name : String,
  default_value : Double,
  min_value : Double,
) -> Double raise DotLayoutError {
  let raw = match option_value {
    Some(value) => value
    None =>
      match graph.get_attr(attr_name) {
        Some(value) => @dot_shared.parse_first_double(value, default_value)
        None => default_value
      }
  }
  if raw < 0.0 {
    raise DotLayoutError::InvalidGraph(
      message="\{attr_name} must be non-negative",
    )
  }
  if raw < min_value { min_value } else { raw }
}

///|
/// Graphviz parity: nodesep/ranksep parse option overrides first, then graph
/// attributes, reject negatives, and clamp with Graphviz minima.
/// Do not change behavior without updating fixtures/tests.
fn resolve_spacing(
  graph : @cgraph.Graph,
  option_nodesep : Double?,
  option_ranksep : Double?,
) -> SpacingResolution raise DotLayoutError {
  let nodesep_in =
    resolve_spacing_scalar(
      graph,
      option_nodesep,
      "nodesep",
      default_nodesep_in(),
      MIN_NODESEP_IN,
    )
  let ranksep_in =
    resolve_spacing_scalar(
      graph,
      option_ranksep,
      "ranksep",
      default_ranksep_in(),
      MIN_RANKSEP_IN,
    )
  { nodesep_in, ranksep_in }
}

///|
/// Graphviz parity: splines mode resolution uses option override first, then
/// graph attribute parsing with Spline fallback.
/// Do not change behavior without updating fixtures/tests.
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
/// Graphviz parity: Stage A root deps keep node geometry and label-port
/// bridges explicit while the input_stage subpackage owns snapshot assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_input_stage_deps() -> InputStageDeps {
  {
    graph_has_edge_labels: @label_metrics.graph_has_edge_labels,
    node_size_for: @node_geometry.node_size,
    swap_node_size: @dot_shared.swap_node_size,
    raw_label_ports_for_node: @label_layout.raw_label_ports_for_node,
    layout_port_offset: @label_layout.layout_port_offset,
    label_text_for: @label_layout.label_text,
  }
}
