///|
fn collect_rank_group_component_nodes(
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
) -> Array[String] {
  let nodes : Array[String] = []
  for rank in rank_keys {
    let names = match groups.get(rank) {
      Some(list) => list
      None => []
    }
    for name in names {
      nodes.push(name)
    }
  }
  nodes
}

///|
fn build_empty_rank_group_map(rank_keys : Array[Int]) -> Map[Int, Array[String]] {
  let empty : Map[Int, Array[String]] = Map::new()
  for rank in rank_keys {
    empty[rank] = []
  }
  empty
}

///|
/// Graphviz parity: component discovery follows Graphviz's decompose-style DFS
/// over edge and flat-constraint neighborhoods with cluster rankleader closure.
/// Do not change behavior without updating fixtures/tests.
fn discover_rank_group_components_graphviz(
  nodes : Array[String],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_ranks : Map[String, Int],
  node_order : Map[String, Int],
  cluster_keys : Map[String, String],
  cluster_skeleton : Map[String, Bool],
  flat_constraints : Map[String, Bool],
  graphviz_out_neighbors? : Map[String, Array[String]] = Map::new(),
  graphviz_in_neighbors? : Map[String, Array[String]] = Map::new(),
) -> Array[Array[String]] {
  let prepared = prepare_rank_group_component_discovery_graphviz(
    nodes,
    edge_tail,
    edge_head,
    node_ranks,
    node_order,
    cluster_keys,
    cluster_skeleton,
    flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
  )
  discover_rank_group_components_from_neighbors_graphviz(
    nodes,
    prepared.ordered_nodes,
    cluster_keys,
    cluster_skeleton,
    prepared.cluster_skeleton_nodes,
    prepared.out_neighbors,
    prepared.in_neighbors,
    prepared.flat_out,
    prepared.flat_in,
  )
}
