///|
pub fn collect_cluster_members(
  cluster_graphs : Map[String, @cgraph.Graph],
) -> Map[String, Map[String, Bool]] {
  let members : Map[String, Map[String, Bool]] = Map::new()
  for name, cluster_graph in cluster_graphs {
    let set : Map[String, Bool] = Map::new()
    @cluster_graph.collect_graph_nodes(cluster_graph, set)
    if set.length() > 0 {
      members[name] = set
    }
  }
  members
}

///|
pub struct TopClustersCollected {
  cluster_graphs : Map[String, @cgraph.Graph]
  top_clusters : Array[String]
}

///|
pub fn collect_top_clusters(source : @cgraph.Graph) -> TopClustersCollected {
  let cluster_maps = @cluster_graph.collect_cluster_graph_maps(source)
  let cluster_graphs = cluster_maps.cluster_graphs
  let cluster_parents = cluster_maps.cluster_parents
  let root_cluster_name = if @cluster_graph.is_cluster_graph(source) {
    match source.name() {
      Some(value) => value
      None => ""
    }
  } else {
    ""
  }
  let top_clusters : Array[String] = []
  for name, parent in cluster_parents {
    match parent {
      None => if name != root_cluster_name { top_clusters.push(name) }
      Some(_) => ()
    }
  }
  { cluster_graphs, top_clusters }
}

///|
/// Graphviz parity: each node is assigned to at most one top-level cluster for
/// clustered rank projection.
/// Do not change behavior without updating fixtures/tests.
pub fn build_node_cluster_index(
  top_clusters : Array[String],
  cluster_members : Map[String, Map[String, Bool]],
) -> Map[String, String] {
  let node_cluster : Map[String, String] = Map::new()
  for cluster_name in top_clusters {
    match cluster_members.get(cluster_name) {
      Some(members) =>
        for name, _ in members {
          node_cluster[name] = cluster_name
        }
      None => ()
    }
  }
  node_cluster
}
