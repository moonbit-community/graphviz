///|
/// Graphviz parity: edge-port sample bundle keeps x-offset and port-order
/// arrays aligned by edge traversal order for tie-break and median passes.
type EdgePortSampleBundle = @ordering.EdgePortSampleBundle

///|
/// Graphviz parity: edge-port sampling context keeps rankdir lookup, node
/// index, and per-node port offsets fixed before edge endpoint iteration.
/// Do not change behavior without updating fixtures/tests.
priv struct EdgePortSamplingContext {
  rankdir : RankDir
  nodes_by_name : Map[String, @cgraph.Node]
  port_offsets : Map[String, Map[String, RecordPort]]
}

///|
fn build_edge_port_sampling_context(
  nodes : Array[@cgraph.Node],
  sizes : Map[String, NodeSize],
) -> EdgePortSamplingContext {
  let rankdir =
    if nodes.length() > 0 { @dot_shared.graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
  let nodes_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    nodes_by_name[node.name()] = node
  }
  {
    rankdir,
    nodes_by_name,
    port_offsets: port_offsets_for_nodes(nodes, sizes),
  }
}

///|
/// Graphviz parity: shared edge-port sampling setup keeps endpoint remap and
/// per-edge iteration order identical for both x-offset and port-order passes.
/// Graphviz parity: x-offset and port-order endpoint samples are computed from
/// the same endpoint projection/context snapshot for deterministic pairing.
/// Do not change behavior without updating fixtures/tests.
fn build_edge_port_sample_bundle(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> EdgePortSampleBundle {
  let sampling_context = build_edge_port_sampling_context(nodes, sizes)
  @ordering.build_edge_port_sample_bundle(
    edges,
    edge_tail,
    edge_head,
    (name, port) =>
      edge_port_offset(
        name,
        port,
        sampling_context.port_offsets,
        sizes,
        sampling_context.rankdir,
        sampling_context.nodes_by_name,
      ),
    (name, port) =>
      edge_port_order(
        name,
        port,
        sampling_context.port_offsets,
        sizes,
        sampling_context.rankdir,
        sampling_context.nodes_by_name,
      ),
  )
}
