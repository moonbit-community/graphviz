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
