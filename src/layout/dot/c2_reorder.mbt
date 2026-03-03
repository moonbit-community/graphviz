///|
/// Stage C Phase C2 split: ordering-stage reorder
/// and materialization helpers for root mincross flow.

///|
/// Stage C Phase C2 split: shared Graphviz ND_out/ND_in neighbor map bundle
/// reused by C2 materialization and C3 local-cluster neighbor replay.
priv struct GraphvizNeighborMaps {
  out_neighbors : Map[String, Array[String]]
  in_neighbors : Map[String, Array[String]]
}

///|
/// Stage C Phase C2 split: order-reorder/materialize
/// runtime data types shared with clustered root stages.

///|
priv struct OrderReorderContext {
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_nodes : Array[String]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  creation_order : Array[String]
  order_node_order : Map[String, Int]
}

///|
priv struct OrderMaterializationData {
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_edges_out_unmapped : Array[@cgraph.Edge]
  order_edge_tail_out_unmapped : Array[String]
  order_edge_head_out_unmapped : Array[String]
  order_edge_tail_port_x_unmapped : Array[Double]
  order_edge_head_port_x_unmapped : Array[Double]
  order_edge_tail_port_order_unmapped : Array[Double]
  order_edge_head_port_order_unmapped : Array[Double]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  order_flat_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: order-graph rebuild uses GD_nlist-derived creation order
/// and build_ranks seed order before mapped/unmapped edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_order_reorder_context(
  order_groups : Map[Int, Array[String]],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  has_clusters : Bool,
  base_order_index : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> OrderReorderContext {
  let order_rank_keys = @ordering.collect_rank_keys(order_groups)
  let order_ranks = @ordering.build_node_ranks(order_groups)
  let order_nodes =
    @ordering.build_order_nodes_from_groups(order_groups, order_rank_keys)
  let order_graph_output =
    @ordering.build_order_graph_and_nodes("order_graph", order_nodes)
  let order_graph = order_graph_output.order_graph
  let order_node_map = order_graph_output.order_node_map
  let order_graph_unmapped_output =
    @ordering.build_order_graph_and_nodes("order_graph_unmapped", order_nodes)
  let order_graph_unmapped = order_graph_unmapped_output.order_graph
  let order_node_map_unmapped = order_graph_unmapped_output.order_node_map
  let creation_order : Array[String] = []
  let mut creation_idx = nlist_order.length()
  while creation_idx > 0 {
    creation_idx = creation_idx - 1
    creation_order.push(nlist_order[creation_idx])
  }
  // Graphviz parity: build_ranks node-order seed prioritizes GD_nlist then
  // fills with nlist/order_groups/base order; rank=same ND_order normalization
  // is applied only on clustered reorder paths.
  let order_node_order : Map[String, Int] = Map::new()
  let mut order_idx = 0
  for name in gdnlist_order {
    order_node_order[name] = order_idx
    order_idx = order_idx + 1
  }
  for name in nlist_order {
    if order_node_order.get(name) is None {
      order_node_order[name] = order_idx
      order_idx = order_idx + 1
    }
  }
  // Graphviz parity: fall back to GD_nlist order for real nodes missing from nlist.
  for name, idx in node_order {
    if real_nodes.get(name) is Some(_) && order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  let order_index = @ordering.build_order_index(order_groups)
  for name, idx in order_index {
    if order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  // Graphviz parity: seed missing real-node order from initial rank order;
  // GD_nlist order remains the primary source.
  for name, idx in base_order_index {
    if real_nodes.get(name) is Some(_) && order_node_order.get(name) is None {
      order_node_order[name] = idx
    }
  }
  if has_clusters {
    // Graphviz parity: non-cluster root reorder keeps GD_nlist-derived order
    // (world.gv) and does not re-normalize ND_order by rank=same declaration.
    @ordering.apply_rank_same_order_nodes(
      order_node_order,
      rank_same_groups,
      rank_same_order,
      port_edge_nodes,
    )
  }
  {
    order_rank_keys,
    order_ranks,
    order_nodes,
    order_graph,
    order_node_map,
    order_graph_unmapped,
    order_node_map_unmapped,
    creation_order,
    order_node_order,
  }
}

///|
/// Graphviz parity: mapped/unmapped order-edge materialization and neighbor
/// maps must follow GD_nlist/AGSEQ traversal before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_graphviz_neighbors(
  order_nodes : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  edge_creation_order : Array[(String, String)],
) -> GraphvizNeighborMaps {
  // Graphviz parity: ND_out/ND_in neighbor order follows edge insertion (AGSEQ).
  let graphviz_out_neighbors : Map[String, Array[String]] = Map::new()
  let graphviz_in_neighbors : Map[String, Array[String]] = Map::new()
  for name in order_nodes {
    graphviz_out_neighbors[name] = []
    graphviz_in_neighbors[name] = []
  }
  for tail, entries in order_edges_by_tail {
    let heads : Array[String] = []
    for entry in entries {
      let (_t, h, _pen, _constraint, _tail_port_x, _head_port_x, _tail_port_order, _head_port_order) =
        entry
      heads.push(h)
    }
    graphviz_out_neighbors[tail] = heads
  }
  let in_entries : Map[String, Array[String]] = Map::new()
  for edge in edge_creation_order {
    let (tail, head) = edge
    match in_entries.get(head) {
      Some(list) => list.push(tail)
      None => in_entries[head] = [tail]
    }
  }
  for head, entries in in_entries {
    graphviz_in_neighbors[head] = entries
  }
  {
    out_neighbors: graphviz_out_neighbors,
    in_neighbors: graphviz_in_neighbors,
  }
}

///|
/// Graphviz parity: mapped/unmapped order-edge materialization and neighbor
/// maps must follow GD_nlist/AGSEQ traversal before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_inputs(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
  real_nodes : Map[String, Bool],
  order_nodes : Array[String],
  edge_creation_order : Array[(String, String)],
  cluster_meta : ClusterMetadata,
  gdnlist_order : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  nodes : Array[@cgraph.Node],
  order_node_order : Map[String, Int],
) -> OrderMaterializationData {
  // Graphviz parity: mapped/unmapped order-edge arrays are materialized from
  // GD_nlist tail order against remapped and non-remapped order graphs.
  let mapped_edges =
    @ordering.collect_order_edges_for_tails(
      nlist_order,
      order_edges_by_tail,
      order_graph,
      order_node_map,
    )
  let unmapped_edges =
    @ordering.collect_order_edges_for_tails(
      nlist_order,
      order_edges_by_tail_unmapped,
      order_graph_unmapped,
      order_node_map_unmapped,
    )
  let order_edges_out = mapped_edges.order_edges_out
  let order_edge_tail_out = mapped_edges.order_edge_tail_out
  let order_edge_head_out = mapped_edges.order_edge_head_out
  let order_edge_tail_port_x = mapped_edges.order_edge_tail_port_x
  let order_edge_head_port_x = mapped_edges.order_edge_head_port_x
  let order_edge_tail_port_order = mapped_edges.order_edge_tail_port_order
  let order_edge_head_port_order = mapped_edges.order_edge_head_port_order
  let order_edges_out_unmapped = unmapped_edges.order_edges_out
  let order_edge_tail_out_unmapped = unmapped_edges.order_edge_tail_out
  let order_edge_head_out_unmapped = unmapped_edges.order_edge_head_out
  let order_edge_tail_port_x_unmapped = unmapped_edges.order_edge_tail_port_x
  let order_edge_head_port_x_unmapped = unmapped_edges.order_edge_head_port_x
  let order_edge_tail_port_order_unmapped =
    unmapped_edges.order_edge_tail_port_order
  let order_edge_head_port_order_unmapped =
    unmapped_edges.order_edge_head_port_order
  let graphviz_neighbors =
    build_materialized_graphviz_neighbors(
      order_nodes,
      order_edges_by_tail,
      edge_creation_order,
    )
  let graphviz_out_neighbors = graphviz_neighbors.out_neighbors
  let graphviz_in_neighbors = graphviz_neighbors.in_neighbors
  let order_flat_constraints : Map[String, Bool] = Map::new()
  for key, value in cluster_meta.flat_constraints {
    order_flat_constraints[key] = value
  }
  // Graphviz parity: Graphviz neighbor maps and flat constraints are derived
  // before unconstrained-node seed-order overrides for build_ranks seeding.
  apply_unconstrained_overrides(
    gdnlist_order,
    real_nodes,
    order_nodes,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    cluster_meta.rank_same_groups,
    edge_tail,
    edge_head,
    nodes,
    cluster_meta.intercluster_keys,
    order_node_order,
  )
  {
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_flat_constraints,
  }
}
