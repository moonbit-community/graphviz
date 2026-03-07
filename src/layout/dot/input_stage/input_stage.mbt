///|
type RankDir = @rankdir.RankDir
type SplinesMode = @shared.SplinesMode
type RecordOrientation = @shared.RecordOrientation
type LayoutPrep = @shared.LayoutPrep
type NodeSize = @node_primitives.NodeSize

///|
/// Graphviz parity: Stage A owns graph-attribute validation, option
/// canonicalization, and snapshot/geometry assembly; the root package keeps
/// only public API error mapping and cross-stage orchestration.
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

priv struct InputStageInput {
  graph : @cgraph.Graph
  rankdir : RankDir
  nodesep_in : Double
  ranksep_in : Double
  splines : SplinesMode
}

priv struct SpacingResolution {
  nodesep_in : Double
  ranksep_in : Double
}

priv struct SizeMaps {
  output_sizes : Map[String, NodeSize]
  order_sizes : Map[String, NodeSize]
  sizes : Map[String, NodeSize]
}

priv struct PortOrderTotal {
  sum : Double
  count : Int
}

priv struct PortOrderMetadata {
  positions : Map[String, Double]
  contributions : Map[String, Array[(String, Double)]]
}

priv struct RecordPortOrderInput {
  nodes : Array[@cgraph.Node]
  output_sizes : Map[String, NodeSize]
  rankdir : RankDir
  record_orientation : RecordOrientation
}

priv struct PortOrderContribInput {
  edges : Array[@cgraph.Edge]
  record_port_order : Map[String, Map[String, Double]]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

priv struct PortOrderMetadataInput {
  rankdir : RankDir
  has_port_edges : Bool
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  output_sizes : Map[String, NodeSize]
  record_orientation : RecordOrientation
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
        match validate_nonnegative_double_attr(
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
        match validate_nonnegative_double_attr(
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
fn resolve_rankdir(
  graph : @cgraph.Graph,
  option_rankdir : RankDir?,
) -> RankDir {
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
  let nodesep_in =
    match resolve_spacing_scalar(
      graph,
      option_nodesep,
      "nodesep",
      DEFAULT_NODESEP_IN,
      MIN_NODESEP_IN,
    ) {
      Ok(value) => value
      Err(message) => return Err(message)
    }
  let ranksep_in =
    match resolve_spacing_scalar(
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
    prepare_layout_inputs(
      {
        graph,
        rankdir,
        nodesep_in: spacing.nodesep_in,
        ranksep_in: spacing.ranksep_in,
        splines,
      },
    ),
  )
}

///|
/// Graphviz parity: Stage A input snapshot assembly keeps node/edge capture,
/// size-map derivation, and port-order metadata collection in the same order as
/// the original root-stage pipeline.
/// Do not change behavior without updating fixtures/tests.
fn prepare_layout_inputs(
  input : InputStageInput,
) -> LayoutPrep {
  let graph = input.graph
  let nodes = graph.nodes()
  let edges = graph.edges()
  let edge_flags = @shared.scan_edge_flags(edges)
  let has_edge_labels = @edge_label_metrics.graph_has_edge_labels(edges)
  let node_order = build_node_order(nodes, input.rankdir)
  let record_orientation = @shared.record_layout_orientation(input.rankdir)
  let size_maps =
    build_size_maps(nodes, input.rankdir, record_orientation)
  let port_order_metadata =
    build_port_order_metadata(
      {
        rankdir: input.rankdir,
        has_port_edges: edge_flags.has_port_edges,
        nodes,
        edges,
        output_sizes: size_maps.output_sizes,
        record_orientation,
      },
    )
  {
    rankdir: input.rankdir,
    nodesep_in: input.nodesep_in,
    ranksep_in: input.ranksep_in,
    splines: input.splines,
    nodes,
    edges,
    has_dotted_edges: edge_flags.has_dotted_edges,
    has_port_edges: edge_flags.has_port_edges,
    has_edge_labels,
    node_order,
    record_orientation,
    output_sizes: size_maps.output_sizes,
    order_sizes: size_maps.order_sizes,
    sizes: size_maps.sizes,
    port_order_positions: port_order_metadata.positions,
    port_order_contrib: port_order_metadata.contributions,
  }
}
///|
/// Graphviz parity: node-order seeds follow GD_nlist creation order and apply
/// RL reversal after seeding (matching Graphviz ordering behavior).
/// Do not change behavior without updating fixtures/tests.
fn build_node_order(
  nodes : Array[@cgraph.Node],
  rankdir : RankDir,
) -> Map[String, Int] {
  let node_order : Map[String, Int] = Map::new()
  if rankdir == RankDir::RL {
    let total = nodes.length()
    for i, node in nodes {
      node_order[node.name()] = total - 1 - i
    }
  } else {
    for i, node in nodes {
      node_order[node.name()] = i
    }
  }
  node_order
}

///|
/// Graphviz parity: node size maps for output/order/layout are derived once
/// per node, with LR/RL swapping only applied to layout-time sizes.
/// Do not change behavior without updating fixtures/tests.
fn build_size_maps(
  nodes : Array[@cgraph.Node],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> SizeMaps {
  let output_sizes : Map[String, NodeSize] = Map::new()
  let order_sizes : Map[String, NodeSize] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let size = @node_geometry.node_size(node, record_orientation)
    output_sizes[node.name()] = size
    order_sizes[node.name()] = size
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        @node_primitives.swap_node_size(size)
      } else {
        size
      }
  }
  { output_sizes, order_sizes, sizes }
}



///|
fn build_node_port_order(
  node : @cgraph.Node,
  size : NodeSize,
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, Double] {
  let raw_ports =
    @label_layout.raw_label_ports_for_node(
      node,
      { x: 0.0, y: 0.0 },
      size,
      record_orientation,
    )
  let order_map : Map[String, Double] = Map::new()
  for port_name, port in raw_ports {
    let offset = @port_geometry.layout_port_offset(port.center, rankdir)
    order_map[port_name] = offset.x
  }
  order_map
}

///|
/// Graphviz parity: record/html nodes expose per-port horizontal order offsets
/// (layout_port_offset.x) used by later opposite-endpoint averaging.
/// Do not change behavior without updating fixtures/tests.
fn build_record_port_order_map(
  input : RecordPortOrderInput,
) -> Map[String, Map[String, Double]] {
  let record_port_order : Map[String, Map[String, Double]] = Map::new()
  for node in input.nodes {
    let label = @label_attrs.label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    if has_html || @record_geometry.is_record_shape(node) {
      let name = node.name()
      let size =
        @shared.resolve_node_output_size(
          input.output_sizes,
          node,
          input.record_orientation,
          @node_geometry.node_size,
        )
      let order_map =
        build_node_port_order(
          node,
          size,
          input.rankdir,
          input.record_orientation,
        )
      record_port_order[name] = order_map
    }
  }
  record_port_order
}

///|
fn lookup_record_port_order(
  record_port_order : Map[String, Map[String, Double]],
  anchor : String,
  port : @cgraph.Port?,
) -> Double? {
  match port {
    Some(value) =>
      match value.name {
        Some(port_name) =>
          match record_port_order.get(anchor) {
            Some(ports) => ports.get(port_name)
            None => None
          }
        None => None
      }
    None => None
  }
}

///|
/// Graphviz parity: edge-side port-order contributions are accumulated from
/// explicit record/html ports onto opposite endpoints before averaging.
/// Do not change behavior without updating fixtures/tests.
fn accumulate_port_order_contrib(
  input : PortOrderContribInput,
) -> Map[String, PortOrderTotal] {
  let order_sum : Map[String, PortOrderTotal] = Map::new()
  let update_order = (target : String, anchor : String, port : @cgraph.Port?) => {
    match lookup_record_port_order(input.record_port_order, anchor, port) {
      Some(order) => {
        let current = match order_sum.get(target) {
          Some(value) => value
          None => { sum: 0.0, count: 0 }
        }
        order_sum[target] = {
          sum: current.sum + order,
          count: current.count + 1,
        }
        match input.port_order_contrib.get(target) {
          Some(list) => list.push((anchor, order))
          None => input.port_order_contrib[target] = [(anchor, order)]
        }
      }
      None => ()
    }
  }
  for edge in input.edges {
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    if @edge_identity.port_is_explicit(edge.tail_port()) &&
      @record_geometry.is_record_shape(edge.tail()) {
      update_order(head_name, tail_name, edge.tail_port())
    }
    if @edge_identity.port_is_explicit(edge.head_port()) &&
      @record_geometry.is_record_shape(edge.head()) {
      update_order(tail_name, head_name, edge.head_port())
    }
  }
  order_sum
}

///|
/// Graphviz parity: LR/RL explicit-port hints are computed by accumulating
/// opposite-endpoint contributions and averaging per-target totals.
/// Do not change behavior without updating fixtures/tests.
fn compute_port_order_positions(
  input : PortOrderMetadataInput,
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> Map[String, Double] {
  let record_port_order =
    build_record_port_order_map(
      {
        nodes: input.nodes,
        output_sizes: input.output_sizes,
        rankdir: input.rankdir,
        record_orientation: input.record_orientation,
      },
    )
  let order_sum =
    accumulate_port_order_contrib(
      {
        edges: input.edges,
        record_port_order,
        port_order_contrib,
      },
    )
  let positions : Map[String, Double] = Map::new()
  for name, entry in order_sum {
    if entry.count > 0 {
      positions[name] = entry.sum / entry.count.to_double()
    }
  }
  positions
}

///|
/// Graphviz parity: record/html port order hints are collected for LR/RL only
/// when explicit ports exist, then averaged onto opposite endpoints.
/// Do not change behavior without updating fixtures/tests.
fn build_port_order_metadata(
  input : PortOrderMetadataInput,
) -> PortOrderMetadata {
  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  let port_order_positions =
    if (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
      input.has_port_edges {
      compute_port_order_positions(input, port_order_contrib)
    } else {
      Map::new()
    }
  { positions: port_order_positions, contributions: port_order_contrib }
}
