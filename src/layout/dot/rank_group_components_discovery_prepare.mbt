///|
/// Graphviz parity: prepare decompose inputs with Graphviz-compatible node
/// ordering, edge neighborhoods, flat constraints, and cluster rankleaders.
/// Do not change behavior without updating fixtures/tests.
fn prepare_rank_group_component_discovery_graphviz(
  nodes : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
) -> RankGroupComponentDiscoveryPrepared {
  let (ordered_nodes, fallback_order) = build_rank_group_component_discovery_order(
    nodes,
    node_order,
  )
  let (out_neighbors, in_neighbors, node_set) =
    build_rank_group_component_discovery_neighbors(
      nodes,
      edge_tail,
      edge_head,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
    )
  let cluster_skeleton_nodes = collect_rank_group_component_skeleton_nodes(
    ordered_nodes,
    cluster_keys,
    cluster_skeleton,
    node_ranks,
    node_order,
    fallback_order,
  )
  let (flat_out, flat_in) = build_rank_group_component_flat_constraint_neighbors(
    nodes,
    node_set,
    flat_constraints,
  )
  {
    ordered_nodes,
    out_neighbors,
    in_neighbors,
    flat_out,
    flat_in,
    cluster_skeleton_nodes,
  }
}
