///|
/// Stage C Phase C2 split: ordering-stage reorder
/// and materialization helpers for root mincross flow.

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
) -> @ordering.OrderMaterializationData {
  let materialized =
    @ordering.build_order_materialization_data(
      {
        nlist_order,
        order_edges_by_tail,
        order_graph,
        order_node_map,
        order_edges_by_tail_unmapped,
        order_graph_unmapped,
        order_node_map_unmapped,
        order_nodes,
        edge_creation_order,
        flat_constraints: cluster_meta.flat_constraints,
      },
    )
  // Graphviz parity: Graphviz neighbor maps and flat constraints are derived
  // before unconstrained-node seed-order overrides for build_ranks seeding.
  apply_unconstrained_overrides(
    gdnlist_order,
    real_nodes,
    order_nodes,
    materialized.graphviz_out_neighbors,
    materialized.graphviz_in_neighbors,
    cluster_meta.rank_same_groups,
    edge_tail,
    edge_head,
    nodes,
    cluster_meta.intercluster_keys,
    order_node_order,
  )
  materialized
}
