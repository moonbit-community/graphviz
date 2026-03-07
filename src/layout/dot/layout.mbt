///|
pub fn DotLayoutOptions::default() -> DotLayoutOptions {
  { rankdir: None, nodesep: None, ranksep: None, splines: None }
}

///|
/// Stage A input preparation: option parsing stays in the root dot package,
/// while snapshot/geometry assembly lives in the input_stage subpackage.

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
        @numeric.parse_first_double(value, 0.0),
      )
    None => ()
  }
  match graph.get_attr("ranksep") {
    Some(value) =>
      validate_nonnegative_attr(
        "graph",
        "ranksep",
        value,
        @numeric.parse_first_double(value, 0.0),
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
          @numeric.parse_first_double(value, 0.0),
        )
      None => ()
    }
    match node.get_attr("height") {
      Some(value) =>
        validate_nonnegative_attr(
          "node \{node.name()}",
          "height",
          value,
          @numeric.parse_first_double(value, 0.0),
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
          @numeric.parse_first_double(value, 0.0),
        )
      None => ()
    }
    match edge.get_attr("weight") {
      Some(value) =>
        validate_nonnegative_attr(
          owner,
          "weight",
          value,
          @numeric.parse_first_double(value, 0.0),
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
        Some(value) => @numeric.parse_first_double(value, default_value)
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
/// Graphviz parity: dot layout orchestration aligned to refs/graphviz/lib/dotgen/dotinit.c
/// (dot_layout/doDot) + lib/common/postproc.c (gv_postprocess).
/// Do not change behavior without updating fixtures/tests.
pub fn layout_dot(
  graph : @cgraph.Graph,
  options? : DotLayoutOptions = DotLayoutOptions::default(),
) -> DotLayoutGraph raise DotLayoutError {
  let opts = options
  validate_layout_graph(graph)
  @label_layout.reset_label_caches()
  let prep = prepare_layout_inputs(graph, opts)
  let rank_stage_output =
    @ordering_stage.compute_dot_rank_stage({ graph, prep })
  let rank_data = rank_stage_output.rank_data
  let rank_heights = rank_stage_output.rank_heights
  let cluster_meta = rank_stage_output.cluster_meta
  let ordering = rank_stage_output.ordering
  let positions_state =
    @position_stage.compute_positions(
      {
        graph,
        prep,
        rank_data,
        rank_heights,
        cluster_meta,
        ordering,
      },
    )
  let routing_stage_output =
    @routing_stage.compute_dot_routing_stage(
      {
        graph,
        prep,
        rank_data,
        rank_heights,
        cluster_meta,
        ordering,
        positions_state,
      },
      @routing_stage.build_dot_routing_stage_deps(),
    )
  dot_layout_graph_from_layout_tree(
    @finalization.finalize_layout_from_sources(
      {
        graph,
        prep,
        rank_data,
        rank_heights,
        positions_state,
        routing_stage_output,
      },
    ),
  )
}

///|
/// Bridge between the public root layout type and the internal shared layout
/// tree used by tree-heavy subpackages.

type LayoutTree = @dot_shared.LayoutTree

///|
fn dot_layout_graph_from_layout_tree(layout : LayoutTree) -> DotLayoutGraph {
  let subgraphs : Array[DotLayoutGraph] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(dot_layout_graph_from_layout_tree(subgraph))
  }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs,
  }
}

///|
fn layout_tree_from_dot_layout_graph(layout : DotLayoutGraph) -> LayoutTree {
  let subgraphs : Array[LayoutTree] = []
  for subgraph in layout.subgraphs {
    subgraphs.push(layout_tree_from_dot_layout_graph(subgraph))
  }
  {
    graph: layout.graph,
    bbox: layout.bbox,
    label_pos: layout.label_pos,
    nodes: layout.nodes,
    edges: layout.edges,
    subgraphs,
  }
}

///|
/// Graphviz parity: final writeback preserves Graphviz attribute emission order
/// for graph/node/edge geometry and label positions.
/// Do not change behavior without updating fixtures/tests.
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  @finalization.apply_layout_tree_writeback(
    layout_tree_from_dot_layout_graph(self),
  )
}
