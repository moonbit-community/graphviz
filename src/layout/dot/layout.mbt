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
fn set_edge_label_pos_if_present(
  edge : @cgraph.Edge,
  label_attr : String,
  pos_attr : String,
  pos : @geom.Point?,
) -> Unit {
  match pos {
    Some(value) =>
      match edge.get_attr(label_attr) {
        Some(text) => if text != "" { edge.set_attr(pos_attr, @dot_shared.format_point(value)) }
        None => ()
      }
    None => ()
  }
}

///|
/// Graphviz parity: final writeback preserves Graphviz attribute emission order
/// for graph/node/edge geometry and label positions.
/// Do not change behavior without updating fixtures/tests.
pub fn DotLayoutGraph::apply(self : DotLayoutGraph) -> Unit {
  let mut write_bb = self.graph.is_root()
  if !write_bb {
    match self.graph.name() {
      Some(name) => if name.has_prefix("cluster") { write_bb = true }
      None => ()
    }
  }
  let record_orientation =
    @dot_shared.record_layout_orientation(@dot_shared.graph_rankdir(self.graph))
  if write_bb {
    self.graph.set_attr("bb", @dot_shared.format_rect(self.bbox))
  }
  if write_bb {
    match @label_metrics.graph_label_metrics(self.graph) {
      Some(metrics) => {
        self.graph.set_attr("lwidth", @dot_shared.format_fixed(metrics.width_pt / 72.0, 2))
        self.graph.set_attr(
          "lheight",
          @dot_shared.format_fixed(metrics.height_pt / 72.0, 2),
        )
      }
      None => ()
    }
  }
  match self.label_pos {
    Some(pos) => self.graph.set_attr("lp", @dot_shared.format_point(pos))
    None => ()
  }
  for node_layout in self.nodes {
    let node = node_layout.node
    let output_pos : @geom.Point = match node.get_attr("shape") {
      // Graphviz rounds star-node centroids up at the 0.001 boundary.
      Some(shape) if shape.to_lower() == "star" =>
        { x: node_layout.pos.x, y: node_layout.pos.y + 0.0005 }
      _ => node_layout.pos
    }
    node.set_attr("pos", @dot_shared.format_point(output_pos))
    node.set_attr("width", @dot_shared.format_dim(node_layout.width_in))
    node.set_attr("height", @dot_shared.format_dim(node_layout.height_in))
    let is_mrecord = match node.get_attr("shape") {
      Some(value) => value.to_lower() == "mrecord"
      None => false
    }
    if @record_geometry.is_record_shape(node) &&
      !is_mrecord &&
      !@html_label.is_html_label_text(@label_attrs.label_text(node)) {
      let size = @node_primitives.node_size_from_points(
        node_layout.width_in * 72.0,
        node_layout.height_in * 72.0,
      )
      let rects = @record_layout.record_rects(
        node,
        node_layout.pos,
        size,
        record_orientation,
      )
      if rects.length() > 0 {
        node.set_attr("rects", @dot_shared.format_rects(rects))
      }
    }
    match node_layout.label_pos {
      Some(pos) => node.set_attr("lp", @dot_shared.format_point(pos))
      None => ()
    }
    match node_layout.xlabel_pos {
      Some(pos) => node.set_attr("xlp", @dot_shared.format_point(pos))
      None => ()
    }
  }
  for edge_layout in self.edges {
    let edge = edge_layout.edge
    // Graphviz parity: omit e/s markers when arrowhead/arrowtail is none.
    let include_tail = @edge_semantics.edge_has_tail_marker(edge, self.graph.kind())
    let include_head = @edge_semantics.edge_has_head_marker(edge, self.graph.kind())
    let segments : Array[String] = []
    for spline in edge_layout.splines {
      let parts : Array[String] = []
      if include_tail {
        match spline.start {
          Some(point) => parts.push("s,\{@dot_shared.format_point(point)}")
          None => ()
        }
      }
      if include_head {
        match spline.end {
          Some(point) => parts.push("e,\{@dot_shared.format_point(point)}")
          None => ()
        }
      }
      for point in spline.points {
        parts.push(@dot_shared.format_point(point))
      }
      segments.push(parts.join(" "))
    }
    let pos = segments.join(";")
    edge.set_attr("pos", pos)
    set_edge_label_pos_if_present(edge, "label", "lp", edge_layout.label_pos)
    set_edge_label_pos_if_present(
      edge,
      "headlabel",
      "head_lp",
      edge_layout.head_label_pos,
    )
    set_edge_label_pos_if_present(
      edge,
      "taillabel",
      "tail_lp",
      edge_layout.tail_label_pos,
    )
    set_edge_label_pos_if_present(edge, "xlabel", "xlp", edge_layout.xlabel_pos)
  }
  for subgraph in self.subgraphs {
    subgraph.apply()
  }
}
