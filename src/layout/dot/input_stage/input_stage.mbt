///|
type RankDir = @shared.RankDir
type SplinesMode = @shared.SplinesMode
type RecordOrientation = @shared.RecordOrientation
type LayoutPrep = @shared.LayoutPrep
type NodeSize = @shared.NodeSize
type RecordPort = @shared.RecordPort

///|
/// Graphviz parity: Stage A input payload keeps resolved graph options grouped
/// so the input_stage subpackage owns snapshot/geometry assembly while the root
/// package keeps option parsing and error mapping.
pub(all) struct InputStageInput {
  graph : @cgraph.Graph
  rankdir : RankDir
  nodesep_in : Double
  ranksep_in : Double
  splines : SplinesMode
}

///|
/// Graphviz parity: Stage A deps keep root-owned node geometry and label-port
/// bridges explicit while the subpackage owns input snapshot assembly.
pub(all) struct InputStageDeps {
  graph_has_edge_labels : (Array[@cgraph.Edge]) -> Bool
  node_size_for : (@cgraph.Node, RecordOrientation) -> NodeSize
  swap_node_size : (NodeSize) -> NodeSize
  raw_label_ports_for_node : (
    @cgraph.Node,
    @geom.Point,
    NodeSize,
    RecordOrientation,
  ) -> Map[String, RecordPort]
  layout_port_offset : (@geom.Point, RankDir) -> @geom.Point
  label_text_for : (@cgraph.Node) -> String
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
/// Graphviz parity: Stage A input snapshot assembly keeps node/edge capture,
/// size-map derivation, and port-order metadata collection in the same order as
/// the original root-stage pipeline.
/// Do not change behavior without updating fixtures/tests.
pub fn prepare_layout_inputs(
  input : InputStageInput,
  deps : InputStageDeps,
) -> LayoutPrep {
  let graph = input.graph
  let nodes = graph.nodes()
  let edges = graph.edges()
  let edge_flags = @shared.scan_edge_flags(edges)
  let has_edge_labels = (deps.graph_has_edge_labels)(edges)
  let node_order = build_node_order(nodes, input.rankdir)
  let record_orientation = @shared.record_layout_orientation(input.rankdir)
  let size_maps =
    build_size_maps(nodes, input.rankdir, record_orientation, deps)
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
      deps,
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
  deps : InputStageDeps,
) -> SizeMaps {
  let output_sizes : Map[String, NodeSize] = Map::new()
  let order_sizes : Map[String, NodeSize] = Map::new()
  let sizes : Map[String, NodeSize] = Map::new()
  for node in nodes {
    let size = (deps.node_size_for)(node, record_orientation)
    output_sizes[node.name()] = size
    order_sizes[node.name()] = size
    sizes[node.name()] =
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        (deps.swap_node_size)(size)
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
  deps : InputStageDeps,
) -> Map[String, Double] {
  let raw_ports =
    (deps.raw_label_ports_for_node)(
      node,
      { x: 0.0, y: 0.0 },
      size,
      record_orientation,
    )
  let order_map : Map[String, Double] = Map::new()
  for port_name, port in raw_ports {
    let offset = (deps.layout_port_offset)(port.center, rankdir)
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
  deps : InputStageDeps,
) -> Map[String, Map[String, Double]] {
  let record_port_order : Map[String, Map[String, Double]] = Map::new()
  for node in input.nodes {
    let label = (deps.label_text_for)(node)
    let has_html = @html_label.is_html_label_text(label)
    if has_html || @shared.is_record_shape(node) {
      let name = node.name()
      let size =
        @shared.resolve_node_output_size(
          input.output_sizes,
          node,
          input.record_orientation,
          deps.node_size_for,
        )
      let order_map =
        build_node_port_order(
          node,
          size,
          input.rankdir,
          input.record_orientation,
          deps,
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
    if @shared.port_is_explicit(edge.tail_port()) &&
      @shared.is_record_shape(edge.tail()) {
      update_order(head_name, tail_name, edge.tail_port())
    }
    if @shared.port_is_explicit(edge.head_port()) &&
      @shared.is_record_shape(edge.head()) {
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
  deps : InputStageDeps,
) -> Map[String, Double] {
  let record_port_order =
    build_record_port_order_map(
      {
        nodes: input.nodes,
        output_sizes: input.output_sizes,
        rankdir: input.rankdir,
        record_orientation: input.record_orientation,
      },
      deps,
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
  deps : InputStageDeps,
) -> PortOrderMetadata {
  let port_order_contrib : Map[String, Array[(String, Double)]] = Map::new()
  let port_order_positions =
    if (input.rankdir == RankDir::LR || input.rankdir == RankDir::RL) &&
      input.has_port_edges {
      compute_port_order_positions(input, port_order_contrib, deps)
    } else {
      Map::new()
    }
  { positions: port_order_positions, contributions: port_order_contrib }
}
