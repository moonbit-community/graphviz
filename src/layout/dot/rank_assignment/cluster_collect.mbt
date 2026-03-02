///|
pub fn collect_cluster_members(
  cluster_graphs : Map[String, @cgraph.Graph],
) -> Map[String, Map[String, Bool]] {
  let members : Map[String, Map[String, Bool]] = Map::new()
  for name, cluster_graph in cluster_graphs {
    let set : Map[String, Bool] = Map::new()
    @shared.collect_graph_nodes(cluster_graph, set)
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
pub fn collect_top_clusters(
  source : @cgraph.Graph,
) -> TopClustersCollected {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  @shared.collect_cluster_graphs(
    source,
    None,
    cluster_graphs,
    cluster_parents,
  )
  let root_cluster_name =
    if @shared.is_cluster_graph(source) {
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
      None =>
        if name != root_cluster_name {
          top_clusters.push(name)
        }
      Some(_) => ()
    }
  }
  { cluster_graphs, top_clusters }
}
