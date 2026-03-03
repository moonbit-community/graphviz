///|
/// Ordering domain: edge-port sampling outputs used by class2 preprocessing.

///|
pub(all) struct OrderingEdgePortData {
  edge_order : Map[String, Int]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
/// Graphviz parity: order-graph edge arrays preserve original edge sequence,
/// then reuse deduplicated order edges for mincross-specific port sampling.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_edge_port_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, @shared.NodeSize],
  compute_port_positions : (Array[@cgraph.Node], Array[@cgraph.Edge], Array[String], Array[String], Map[String, @shared.NodeSize]) -> (Array[Double], Array[Double]),
  compute_port_orders : (Array[@cgraph.Node], Array[@cgraph.Edge], Array[String], Array[String], Map[String, @shared.NodeSize]) -> (Array[Double], Array[Double]),
) -> OrderingEdgePortData {
  let edge_order = collect_edge_order(edges)
  let (edge_tail_port_x, edge_head_port_x) =
    compute_port_positions(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  let (edge_tail_port_order, edge_head_port_order) =
    compute_port_orders(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  let dedup_output =
    dedup_ordering_edges(edges, edge_tail, edge_head)
  let order_edges = dedup_output.order_edges
  let order_edge_tail = dedup_output.order_edge_tail
  let order_edge_head = dedup_output.order_edge_head
  let (order_edge_tail_port_x, order_edge_head_port_x) =
    compute_port_positions(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_sizes,
    )
  let (order_edge_tail_port_order, order_edge_head_port_order) =
    compute_port_orders(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_sizes,
    )
  {
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}
