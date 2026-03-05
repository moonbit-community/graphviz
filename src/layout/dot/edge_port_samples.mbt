///|
/// Dot edge-port sampling helpers shared by ordering (Stage C) and positioning
/// (Stage D) tie-break preprocessing.
priv struct EdgePortSamples {
  tail_values : Array[Double]
  head_values : Array[Double]
}

///|
/// Graphviz parity: edge-port sample bundle keeps x-offset and port-order
/// arrays aligned by edge traversal order for tie-break and median passes.
priv struct EdgePortSampleBundle {
  tail_port_x : Array[Double]
  head_port_x : Array[Double]
  tail_port_order : Array[Double]
  head_port_order : Array[Double]
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
  let port_positions =
    compute_edge_port_samples(
      nodes,
      edges,
      edge_tail,
      edge_head,
      sizes,
      edge_port_offset,
    )
  let port_orders =
    compute_edge_port_samples(
      nodes,
      edges,
      edge_tail,
      edge_head,
      sizes,
      edge_port_order,
    )
  {
    tail_port_x: port_positions.tail_values,
    head_port_x: port_positions.head_values,
    tail_port_order: port_orders.tail_values,
    head_port_order: port_orders.head_values,
  }
}
