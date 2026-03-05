///|
/// Stage C Phase C1 split: edge-port sampling helpers
/// for ordering/xpos tie-break x-offset and port-order projections.

///|
priv struct EdgePortSamples {
  tail_values : Array[Double]
  head_values : Array[Double]
}

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
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
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
fn compute_edge_port_samples(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
  sample_fn : (String, @cgraph.Port?, Map[String, Map[String, RecordPort]], Map[String, NodeSize], RankDir, Map[String, @cgraph.Node]) -> Double,
) -> EdgePortSamples {
  if edges.length() == 0 {
    return { tail_values: [], head_values: [] }
  }
  let sampling_context = build_edge_port_sampling_context(nodes, sizes)
  let endpoint_projection =
    @ordering.build_edge_endpoint_port_projection(
      edges,
      edge_tail,
      edge_head,
    )
  let endpoint_samples =
    @ordering.sample_edge_endpoint_ports(
      endpoint_projection,
      (name, port) =>
        sample_fn(
          name,
          port,
          sampling_context.port_offsets,
          sizes,
          sampling_context.rankdir,
          sampling_context.nodes_by_name,
        ),
    )
  {
    tail_values: endpoint_samples.tail_values,
    head_values: endpoint_samples.head_values,
  }
}

///|
/// Graphviz parity: port x offsets for mincross tie-breaks (mincross.c).
/// Do not change behavior without updating fixtures/tests.
fn compute_edge_port_positions(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> EdgePortSamples {
  // Graphviz parity: per-edge tail/head x-offset samples are emitted in edge
  // sequence order after endpoint-name/port remap.
  compute_edge_port_samples(
    nodes,
    edges,
    edge_tail,
    edge_head,
    sizes,
    edge_port_offset,
  )
}

///|
/// Graphviz parity: port order fractions for mincross medians
/// (shapes.c compassPort + mincross.c VAL/MC_SCALE).
/// Do not change behavior without updating fixtures/tests.
fn compute_edge_port_orders(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
) -> EdgePortSamples {
  // Graphviz parity: per-edge tail/head port-order samples are emitted in edge
  // sequence order using the same endpoint remap as tie-break x-offsets.
  compute_edge_port_samples(
    nodes,
    edges,
    edge_tail,
    edge_head,
    sizes,
    edge_port_order,
  )
}
