///|
fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
fn graph_has_cluster(graph : @cgraph.Graph) -> Bool {
  for child in graph.subgraphs() {
    if is_cluster_graph(child) || graph_has_cluster(child) {
      return true
    }
  }
  false
}

///|
fn collect_cluster_graphs(
  graph : @cgraph.Graph,
  parent : String?,
  clusters : Map[String, @cgraph.Graph],
  parents : Map[String, String?],
) -> Unit {
  let mut next_parent = parent
  if is_cluster_graph(graph) {
    match graph.name() {
      Some(name) => {
        clusters[name] = graph
        parents[name] = parent
        next_parent = Some(name)
      }
      None => ()
    }
  }
  for child in graph.subgraphs() {
    collect_cluster_graphs(child, next_parent, clusters, parents)
  }
}

///|
fn collect_graph_nodes(
  graph : @cgraph.Graph,
  nodes_out : Map[String, Bool],
) -> Unit {
  for node in graph.nodes() {
    nodes_out[node.name()] = true
  }
  for child in graph.subgraphs() {
    collect_graph_nodes(child, nodes_out)
  }
}

///|
pub fn collect_cluster_members(
  cluster_graphs : Map[String, @cgraph.Graph],
) -> Map[String, Map[String, Bool]] {
  let members : Map[String, Map[String, Bool]] = Map::new()
  for name, cluster_graph in cluster_graphs {
    let set : Map[String, Bool] = Map::new()
    collect_graph_nodes(cluster_graph, set)
    if set.length() > 0 {
      members[name] = set
    }
  }
  members
}

///|
pub fn collect_top_clusters(
  source : @cgraph.Graph,
) -> (Map[String, @cgraph.Graph], Array[String]) {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(
    source,
    None,
    cluster_graphs,
    cluster_parents,
  )
  let root_cluster_name =
    if is_cluster_graph(source) {
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
  (cluster_graphs, top_clusters)
}
