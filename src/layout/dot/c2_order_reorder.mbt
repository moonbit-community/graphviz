///|
/// Stage C Phase C2 split: ordering-stage reorder
/// and materialization helpers for root mincross flow.

///|
/// Graphviz parity: order-edge trace materialization dispatch context keeps
/// mapped/unmapped materialize+trace payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct MaterializeOrderEdgesWithTraceContext {
  nlist_order : Array[String]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  order_ranks : Map[String, Int]
  real_nodes : Map[String, Bool]
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
/// Graphviz parity: order-reorder context output keeps order-graph handles,
/// creation ordering, and build_ranks node order mapping unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_order_reorder_context_output(
  order_rank_keys : Array[Int],
  order_ranks : Map[String, Int],
  order_nodes : Array[String],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
  creation_order : Array[String],
  order_node_order : Map[String, Int],
) -> OrderReorderContext {
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
/// Graphviz parity: order-reorder context builds paired mapped/unmapped order
/// graphs from the same order-node sequence before edge materialization passes.
/// Do not change behavior without updating fixtures/tests.
fn build_order_graph_pairs_for_reorder_context(
  order_nodes : Array[String],
) -> (
  @cgraph.Graph,
  Map[String, @cgraph.Node],
  @cgraph.Graph,
  Map[String, @cgraph.Node],
) {
  let (order_graph, order_node_map) =
    build_order_graph_and_nodes("order_graph", order_nodes)
  let (order_graph_unmapped, order_node_map_unmapped) =
    build_order_graph_and_nodes("order_graph_unmapped", order_nodes)
  (order_graph, order_node_map, order_graph_unmapped, order_node_map_unmapped)
}


///|
/// Graphviz parity: reorder context derives creation order from GD_nlist and
/// computes build_ranks seed node-order map before order-edge materialization.
/// Do not change behavior without updating fixtures/tests.
fn build_creation_and_node_order_for_reorder_context(
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  node_order : Map[String, Int],
  real_nodes : Map[String, Bool],
  has_clusters : Bool,
  order_groups : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  rank_same_groups : Map[String, Int],
  rank_same_order : Map[String, Int],
  port_edge_nodes : Map[String, Bool],
) -> (Array[String], Map[String, Int]) {
  let creation_order =
    build_reverse_creation_order_from_nlist(nlist_order)
  let order_node_order =
    build_order_node_order_for_build_ranks(
      gdnlist_order,
      nlist_order,
      node_order,
      real_nodes,
      has_clusters,
      order_groups,
      base_order_index,
      rank_same_groups,
      rank_same_order,
      port_edge_nodes,
    )
  (creation_order, order_node_order)
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
  let order_rank_keys = collect_rank_keys(order_groups)
  let order_ranks = build_node_ranks(order_groups)
  let order_nodes =
    build_order_nodes_from_groups(order_groups, order_rank_keys)
  let (order_graph, order_node_map, order_graph_unmapped, order_node_map_unmapped) =
    build_order_graph_pairs_for_reorder_context(order_nodes)
  let (creation_order, order_node_order) =
    build_creation_and_node_order_for_reorder_context(
      nlist_order,
      gdnlist_order,
      node_order,
      real_nodes,
      has_clusters,
      order_groups,
      base_order_index,
      rank_same_groups,
      rank_same_order,
      port_edge_nodes,
    )
  build_order_reorder_context_output(
    order_rank_keys,
    order_ranks,
    order_nodes,
    order_graph,
    order_node_map,
    order_graph_unmapped,
    order_node_map_unmapped,
    creation_order,
    order_node_order,
  )
}

///|
/// Graphviz parity: materialized order-edge output preserves mapped/unmapped
/// arrays plus Graphviz neighbor maps for downstream reorder stages.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors_output(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_flat_constraints : Map[String, Bool],
) -> OrderMaterializationData {
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

///|
/// Graphviz parity: neighbor/constraint output keeps ND_out, ND_in, and flat
/// constraint maps in fixed tuple order for ordering stages.
/// Do not change behavior without updating fixtures/tests.
fn build_order_neighbors_and_flat_constraints_output(
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_flat_constraints : Map[String, Bool],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Bool]) {
  (graphviz_out_neighbors, graphviz_in_neighbors, order_flat_constraints)
}

///|
/// Graphviz parity: Graphviz neighbor maps and flat constraints are derived
/// before unconstrained-node seed-order overrides for build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn build_order_neighbors_and_flat_constraints(
  order_nodes : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  edge_creation_order : Array[(String, String)],
  cluster_meta : ClusterMetadata,
  gdnlist_order : Array[String],
  real_nodes : Map[String, Bool],
  edge_tail : Array[String],
  edge_head : Array[String],
  nodes : Array[@cgraph.Node],
  order_node_order : Map[String, Int],
) -> (Map[String, Array[String]], Map[String, Array[String]], Map[String, Bool]) {
  let (graphviz_out_neighbors, graphviz_in_neighbors) =
    build_graphviz_neighbor_maps(
      order_nodes,
      order_edges_by_tail,
      edge_creation_order,
    )
  let order_flat_constraints =
    clone_flat_constraints(cluster_meta.flat_constraints)
  apply_unconstrained_order_node_overrides(
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
  build_order_neighbors_and_flat_constraints_output(
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_flat_constraints,
  )
}


///|
/// Graphviz parity: mapped/unmapped materialization output preserves tuple field
/// order consumed by downstream ordering/reorder stages.
/// Do not change behavior without updating fixtures/tests.
fn build_materialize_order_edges_with_trace_output(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  (
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
  )
}

///|
/// Graphviz parity: order-edge trace/output phase emits mapped-edge rank traces
/// before returning mapped/unmapped edge tuples in Graphviz field order.
/// Do not change behavior without updating fixtures/tests.
fn materialize_order_edges_with_trace_output_phase(
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  order_ranks : Map[String, Int],
  real_nodes : Map[String, Bool],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  trace_order_edges_with_ranks(
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    real_nodes,
  )
  build_materialize_order_edges_with_trace_output(
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
  )
}


///|
/// Graphviz parity: order-edge trace context builder preserves mapped/unmapped
/// materialization inputs before trace-output dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_materialize_order_edges_with_trace_context(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph : @cgraph.Graph,
  order_node_map : Map[String, @cgraph.Node],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_graph_unmapped : @cgraph.Graph,
  order_node_map_unmapped : Map[String, @cgraph.Node],
  order_ranks : Map[String, Int],
  real_nodes : Map[String, Bool],
) -> MaterializeOrderEdgesWithTraceContext {
  {
    nlist_order,
    order_edges_by_tail,
    order_graph,
    order_node_map,
    order_edges_by_tail_unmapped,
    order_graph_unmapped,
    order_node_map_unmapped,
    order_ranks,
    real_nodes,
  }
}


///|
/// Graphviz parity: mapped/unmapped order-edge arrays are materialized first,
/// and trace emission observes the mapped arrays before neighbor construction.
/// Do not change behavior without updating fixtures/tests.
fn materialize_order_edges_with_trace(
  trace_context : MaterializeOrderEdgesWithTraceContext,
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (
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
  ) =
    materialize_mapped_and_unmapped_order_edges(
      trace_context.nlist_order,
      trace_context.order_edges_by_tail,
      trace_context.order_graph,
      trace_context.order_node_map,
      trace_context.order_edges_by_tail_unmapped,
      trace_context.order_graph_unmapped,
      trace_context.order_node_map_unmapped,
    )
  materialize_order_edges_with_trace_output_phase(
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
    trace_context.order_ranks,
    trace_context.real_nodes,
  )
}


///|
/// Graphviz parity: order-edge materialization phase uses mapped/unmapped
/// GD_nlist-seeded traces before neighbor/constraint reconstruction.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors_materialization_phase(
  context : MaterializedOrderEdgesAndNeighborsContext,
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let trace_context =
    build_materialize_order_edges_with_trace_context(
      context.nlist_order,
      context.order_edges_by_tail,
      context.order_graph,
      context.order_node_map,
      context.order_edges_by_tail_unmapped,
      context.order_graph_unmapped,
      context.order_node_map_unmapped,
      context.order_ranks,
      context.real_nodes,
    )
  materialize_order_edges_with_trace(trace_context)
}

///|
/// Graphviz parity: mapped/unmapped order-edge materialization context keeps
/// Graphviz traversal/neighbor inputs unchanged before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
priv struct MaterializedOrderEdgesAndNeighborsContext {
  nlist_order : Array[String]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  order_ranks : Map[String, Int]
  real_nodes : Map[String, Bool]
  order_nodes : Array[String]
  edge_creation_order : Array[(String, String)]
  cluster_meta : ClusterMetadata
  gdnlist_order : Array[String]
  edge_tail : Array[String]
  edge_head : Array[String]
  nodes : Array[@cgraph.Node]
  order_node_order : Map[String, Int]
}

///|
/// Graphviz parity: materialized order-edge context builder keeps reorder
/// graph fields and neighbor inputs in Graphviz materialization order.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors_context(
  nlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  reorder_context : OrderReorderContext,
  real_nodes : Map[String, Bool],
  edge_creation_order : Array[(String, String)],
  cluster_meta : ClusterMetadata,
  gdnlist_order : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  nodes : Array[@cgraph.Node],
) -> MaterializedOrderEdgesAndNeighborsContext {
  {
    nlist_order,
    order_edges_by_tail,
    order_graph: reorder_context.order_graph,
    order_node_map: reorder_context.order_node_map,
    order_edges_by_tail_unmapped,
    order_graph_unmapped: reorder_context.order_graph_unmapped,
    order_node_map_unmapped: reorder_context.order_node_map_unmapped,
    order_ranks: reorder_context.order_ranks,
    real_nodes,
    order_nodes: reorder_context.order_nodes,
    edge_creation_order,
    cluster_meta,
    gdnlist_order,
    edge_tail,
    edge_head,
    nodes,
    order_node_order: reorder_context.order_node_order,
  }
}


///|
/// Graphviz parity: mapped/unmapped order-edge materialization and neighbor
/// maps must follow GD_nlist/AGSEQ traversal before build_ranks seeding.
/// Do not change behavior without updating fixtures/tests.
fn build_materialized_order_edges_and_neighbors(
  context : MaterializedOrderEdgesAndNeighborsContext,
) -> OrderMaterializationData {
  let (
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
  ) =
    build_materialized_order_edges_and_neighbors_materialization_phase(context)
  let (graphviz_out_neighbors, graphviz_in_neighbors, order_flat_constraints) =
    build_order_neighbors_and_flat_constraints(
      context.order_nodes,
      context.order_edges_by_tail,
      context.edge_creation_order,
      context.cluster_meta,
      context.gdnlist_order,
      context.real_nodes,
      context.edge_tail,
      context.edge_head,
      context.nodes,
      context.order_node_order,
    )
  build_materialized_order_edges_and_neighbors_output(
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
  )
}
