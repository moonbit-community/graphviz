///|
/// Cluster-graph discovery and traversal helpers shared by clustering, rank,
/// positioning, and finalization code.

///|
pub fn is_cluster_graph(graph : @cgraph.Graph) -> Bool {
  match graph.name() {
    Some(name) => name.has_prefix("cluster")
    None => false
  }
}

///|
pub fn graph_has_cluster(graph : @cgraph.Graph) -> Bool {
  for child in graph.subgraphs() {
    if is_cluster_graph(child) || graph_has_cluster(child) {
      return true
    }
  }
  false
}

///|
pub fn collect_cluster_graphs(
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
pub(all) struct ClusterGraphMaps {
  cluster_graphs : Map[String, @cgraph.Graph]
  cluster_parents : Map[String, String?]
}

///|
pub fn collect_cluster_graph_maps(
  graph : @cgraph.Graph,
) -> ClusterGraphMaps {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(graph, None, cluster_graphs, cluster_parents)
  { cluster_graphs, cluster_parents }
}

///|
pub fn collect_cluster_names(
  graph : @cgraph.Graph,
  out : Map[String, Bool],
) -> Unit {
  if is_cluster_graph(graph) {
    match graph.name() {
      Some(name) => out[name] = true
      None => ()
    }
  }
  for child in graph.subgraphs() {
    collect_cluster_names(child, out)
  }
}

///|
pub fn collect_graph_nodes(
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
