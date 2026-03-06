///|
/// Stage A input stage file: stage-local input type definitions plus layout
/// input preparation and canonicalization helpers.

///|
priv struct LayoutPrep {
  rankdir : RankDir
  nodesep_in : Double
  ranksep_in : Double
  splines : SplinesMode
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  has_dotted_edges : Bool
  has_port_edges : Bool
  has_edge_labels : Bool
  node_order : Map[String, Int]
  record_orientation : RecordOrientation
  output_sizes : Map[String, NodeSize]
  order_sizes : Map[String, NodeSize]
  sizes : Map[String, NodeSize]
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
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
  let nodes = graph.nodes()
  let edges = graph.edges()
  let edge_flags =
    scan_edge_flags(edges)
  let has_edge_labels = graph_has_edge_labels(edges)
  let node_order = build_node_order(nodes, rankdir)
  let record_orientation = record_layout_orientation(rankdir)
  let size_maps =
    build_size_maps(nodes, rankdir, record_orientation)
  let port_order_metadata =
    build_port_order_metadata(
      {
        rankdir,
        has_port_edges: edge_flags.has_port_edges,
        nodes,
        edges,
        output_sizes: size_maps.output_sizes,
        record_orientation,
      },
    )
  {
    rankdir,
    nodesep_in: spacing.nodesep_in,
    ranksep_in: spacing.ranksep_in,
    splines,
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
/// Stage A layout input preparation helper builders.

priv struct SpacingResolution {
  nodesep_in : Double
  ranksep_in : Double
}

priv struct EdgeFlags {
  has_dotted_edges : Bool
  has_port_edges : Bool
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
/// Stage A layout input preparation logic and canonicalization helper flow.

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
  // Graphviz parity: late_double clamps nodesep to MIN_NODESEP.
  let nodesep_in =
    resolve_spacing_scalar(
      graph,
      option_nodesep,
      "nodesep",
      default_nodesep_in(),
      MIN_NODESEP_IN,
    )
  // Graphviz parity: ranksep clamps to MIN_RANKSEP.
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
/// Graphviz parity: edge flag scan checks dotted style and explicit ports in
/// edge creation order before downstream ordering setup.
/// Do not change behavior without updating fixtures/tests.
fn scan_edge_flags(
  edges : Array[@cgraph.Edge],
) -> EdgeFlags {
  let mut has_dotted_edges = false
  let mut has_port_edges = false
  for edge in edges {
    match edge.get_attr("style") {
      Some(value) =>
        if value.to_lower().contains("dotted") {
          has_dotted_edges = true
        }
      None => ()
    }
    if !has_port_edges {
      let tail_port = @dot_shared.port_is_explicit(edge.tail_port())
      let head_port = @dot_shared.port_is_explicit(edge.head_port())
      if tail_port || head_port {
        has_port_edges = true
      }
    }
  }
  { has_dotted_edges, has_port_edges }
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
    let size = node_size(node, record_orientation)
    output_sizes[node.name()] = size
    order_sizes[node.name()] = size
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
      swap_node_size(size)
    } else {
      size
    }
  }
  { output_sizes, order_sizes, sizes }
}

///|
/// Graphviz parity: record/html nodes expose per-port horizontal order offsets
/// (layout_port_offset.x) used by later opposite-endpoint averaging.
/// Do not change behavior without updating fixtures/tests.
fn resolve_node_output_size(
  output_sizes : Map[String, NodeSize],
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  let name = node.name()
  match output_sizes.get(name) {
    Some(value) => value
    None => node_size(node, record_orientation)
  }
}

///|
fn build_node_port_order(
  node : @cgraph.Node,
  size : NodeSize,
  rankdir : RankDir,
  record_orientation : RecordOrientation,
) -> Map[String, Double] {
  let raw_ports =
    raw_label_ports_for_node(
      node,
      { x: 0.0, y: 0.0 },
      size,
      record_orientation,
    )
  let order_map : Map[String, Double] = Map::new()
  for port_name, port in raw_ports {
    let offset = layout_port_offset(port.center, rankdir)
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
    let label = label_text(node)
    let has_html = @html_label.is_html_label_text(label)
    if has_html || is_record_shape(node) {
      let name = node.name()
      let size = resolve_node_output_size(input.output_sizes, node, input.record_orientation)
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
    if @dot_shared.port_is_explicit(edge.tail_port()) && is_record_shape(edge.tail()) {
      update_order(head_name, tail_name, edge.tail_port())
    }
    if @dot_shared.port_is_explicit(edge.head_port()) && is_record_shape(edge.head()) {
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
