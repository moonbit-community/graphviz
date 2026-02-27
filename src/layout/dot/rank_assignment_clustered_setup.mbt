///|
/// Graphviz parity: clustered ranking discovers top-level clusters from the
/// collected cluster tree before any fallback/non-cluster branch selection.
/// Do not change behavior without updating fixtures/tests.
fn collect_top_clusters_for_rank_assignment(
  source : @cgraph.Graph,
) -> (Map[String, @cgraph.Graph], Array[String]) {
  let cluster_graphs : Map[String, @cgraph.Graph] = Map::new()
  let cluster_parents : Map[String, String?] = Map::new()
  collect_cluster_graphs(source, None, cluster_graphs, cluster_parents)
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

///|
/// Graphviz parity: each node is assigned to at most one top-level cluster for
/// clustered rank projection.
/// Do not change behavior without updating fixtures/tests.
fn build_node_cluster_index_for_rank_assignment(
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

///|
/// Graphviz parity: clustered ranking first solves each top-level cluster
/// locally, then promotes one local rank-0 leader per cluster.
/// Do not change behavior without updating fixtures/tests.
fn compute_local_cluster_ranks_and_leaders_for_rank_assignment(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  top_clusters : Array[String],
  cluster_graphs : Map[String, @cgraph.Graph],
  cluster_members : Map[String, Map[String, Bool]],
) -> (Map[String, Int], Map[String, String]) {
  let local_ranks : Map[String, Int] = Map::new()
  let cluster_leaders : Map[String, String] = Map::new()
  for cluster_name in top_clusters {
    let members = match cluster_members.get(cluster_name) {
      Some(value) => value
      None => continue
    }
    let cluster_nodes : Array[@cgraph.Node] = []
    for node in nodes {
      if members.get(node.name()) is Some(_) {
        cluster_nodes.push(node)
      }
    }
    if cluster_nodes.length() == 0 {
      continue
    }
    let cluster_edges : Array[@cgraph.Edge] = []
    for edge in edges {
      let tail = edge.tail().name()
      let head = edge.head().name()
      if members.get(tail) is Some(_) && members.get(head) is Some(_) {
        cluster_edges.push(edge)
      }
    }
    let cluster_graph = match cluster_graphs.get(cluster_name) {
      Some(value) => value
      None => source
    }
    let (cluster_tail, cluster_head, cluster_reversed) =
      acyclic_edge_directions(cluster_graph, cluster_nodes, cluster_edges)
    let cluster_ranks = compute_ranks_directed(
      cluster_graph,
      cluster_nodes,
      cluster_edges,
      has_edge_labels,
      cluster_tail,
      cluster_head,
      cluster_reversed,
    )
    for name, rank in cluster_ranks {
      local_ranks[name] = rank
    }
    let mut leader_name : String? = None
    for node in cluster_nodes {
      let name = node.name()
      match cluster_ranks.get(name) {
        Some(rank) =>
          if rank == 0 && leader_name is None {
            leader_name = Some(name)
          }
        None => ()
      }
    }
    let leader =
      match leader_name {
        Some(name) => name
        None => cluster_nodes[0].name()
      }
    cluster_leaders[cluster_name] = leader
  }
  (local_ranks, cluster_leaders)
}
