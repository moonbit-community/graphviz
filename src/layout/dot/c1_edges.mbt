///|
/// Stage C Phase C1 split: ordering-edge materialization,
/// cluster-skeleton seeding, and neighbor-index helpers.

///|
priv struct EdgePortSamples {
  tail_values : Array[Double]
  head_values : Array[Double]
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
  let rankdir =
    if nodes.length() > 0 { graph_rankdir(nodes[0].graph()) } else { RankDir::TB }
  let nodes_by_name : Map[String, @cgraph.Node] = Map::new()
  for node in nodes {
    nodes_by_name[node.name()] = node
  }
  let port_offsets = port_offsets_for_nodes(nodes, sizes)
  let tail_names : Array[String] = []
  let head_names : Array[String] = []
  let tail_ports : Array[@cgraph.Port?] = []
  let head_ports : Array[@cgraph.Port?] = []
  let mut endpoint_idx = 0
  while endpoint_idx < edges.length() {
    let edge = edges[endpoint_idx]
    let (tail_name, head_name) =
      @ordering.edge_endpoints_at(
        edge,
        endpoint_idx,
        edge_tail,
        edge_head,
      )
    let tail_port = @ordering.edge_tail_port_for_name(edge, tail_name)
    let head_port = @ordering.edge_head_port_for_name(edge, head_name)
    tail_names.push(tail_name)
    head_names.push(head_name)
    tail_ports.push(tail_port)
    head_ports.push(head_port)
    endpoint_idx = endpoint_idx + 1
  }
  let tail_samples : Array[Double] = []
  let head_samples : Array[Double] = []
  let mut idx = 0
  while idx < edges.length() {
    tail_samples.push(
      sample_fn(
        tail_names[idx],
        tail_ports[idx],
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      ),
    )
    head_samples.push(
      sample_fn(
        head_names[idx],
        head_ports[idx],
        port_offsets,
        sizes,
        rankdir,
        nodes_by_name,
      ),
    )
    idx = idx + 1
  }
  { tail_values: tail_samples, head_values: head_samples }
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
