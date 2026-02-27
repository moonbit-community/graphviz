///|
/// Graphviz parity: decompose/build_ranks operate per connected component.
/// Do not change behavior without updating fixtures/tests.
fn build_rank_groups_graphviz_components(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  pass : Int,
  flat_constraints : Map[String, Bool],
  flip? : Bool = false,
  graphviz_out_neighbors? : Map[String, Array[String]] = Map::new(),
  graphviz_in_neighbors? : Map[String, Array[String]] = Map::new(),
) -> Map[Int, Array[String]] {
  let nodes = collect_rank_group_component_nodes(rank_keys, groups)
  if nodes.length() == 0 {
    return build_empty_rank_group_map(rank_keys)
  }
  let components = discover_rank_group_components_graphviz(
    nodes,
    edge_tail,
    edge_head,
    node_ranks,
    node_order,
    cluster_keys,
    cluster_skeleton,
    flat_constraints,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
  )
  if components.length() <= 1 {
    return build_rank_groups_graphviz(
      rank_keys,
      groups,
      edge_tail,
      edge_head,
      node_ranks,
      node_order,
      cluster_keys,
      cluster_skeleton,
      pass,
      flip=flip,
      graphviz_out_neighbors=graphviz_out_neighbors,
      graphviz_in_neighbors=graphviz_in_neighbors,
    )
  }
  merge_rank_groups_graphviz_components(
    rank_keys,
    groups,
    edge_tail,
    edge_head,
    node_ranks,
    node_order,
    cluster_keys,
    cluster_skeleton,
    pass,
    flip,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    components,
  )
}
