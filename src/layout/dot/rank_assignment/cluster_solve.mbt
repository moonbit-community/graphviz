///|
pub struct LocalClusterRankResult {
  local_ranks : Map[String, Int]
  cluster_leaders : Map[String, String]
}

///|
priv struct LeaderRankEdge {
  tail_idx : Int
  head_idx : Int
  minlen : Int
  weight : Int
}

///|
pub fn compute_local_cluster_ranks_and_leaders(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  top_clusters : Array[String],
  cluster_graphs : Map[String, @cgraph.Graph],
  cluster_members : Map[String, Map[String, Bool]],
  compute_cluster_ranks : (
    (
      @cgraph.Graph,
      Array[@cgraph.Node],
      Array[@cgraph.Edge],
    ) -> Map[String, Int]
  ),
) -> LocalClusterRankResult {
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
    let cluster_ranks =
      compute_cluster_ranks(cluster_graph, cluster_nodes, cluster_edges)
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
  { local_ranks, cluster_leaders }
}

///|
pub fn solve_clustered_leader_ranks(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  node_cluster : Map[String, String],
  cluster_leaders : Map[String, String],
  local_ranks : Map[String, Int],
  has_edge_labels : Bool,
  back_weight_scale : Int,
  orient_edges_for_names : (
    (
      Array[String],
      Array[String],
      Array[String],
      Array[Bool],
    ) -> AcyclicNameDirections
  ),
) -> Map[String, Int] {
  let rank_graph = @network_simplex.new_graph()
  let rank_index : Map[String, Int] = Map::new()
  let rank_names : Array[String] = []
  for node in nodes {
    let name = node.name()
    let cluster = match node_cluster.get(name) {
      Some(value) => value
      None => ""
    }
    let key =
      if cluster == "" {
        name
      } else {
        match cluster_leaders.get(cluster) {
          Some(value) => value
          None => name
        }
      }
    if rank_index.get(key) is None {
      rank_index[key] = @network_simplex.add_node(rank_graph, key)
      rank_names.push(key)
    }
  }
  let direct_tail : Array[String] = []
  let direct_head : Array[String] = []
  let direct_minlen : Array[Int] = []
  let direct_weight : Array[Int] = []
  let direct_active : Array[Bool] = []
  let mut slack_id = 0
  for edge in edges {
    if !@edge_semantics.edge_is_constraint(edge) {
      continue
    }
    let tail_name = edge.tail().name()
    let head_name = edge.head().name()
    let tail_cluster = match node_cluster.get(tail_name) {
      Some(value) => value
      None => ""
    }
    let head_cluster = match node_cluster.get(head_name) {
      Some(value) => value
      None => ""
    }
    let minlen_value = @edge_semantics.edge_minlen(edge)
    let minlen = if has_edge_labels { minlen_value * 2 } else { minlen_value }
    let weight = @edge_semantics.edge_weight(edge)
    if tail_cluster == head_cluster {
      if tail_cluster == "" && tail_name != head_name {
        direct_tail.push(tail_name)
        direct_head.push(head_name)
        direct_minlen.push(minlen)
        direct_weight.push(weight)
        direct_active.push(true)
      }
      continue
    }
    let tail_leader =
      if tail_cluster == "" {
        tail_name
      } else {
        match cluster_leaders.get(tail_cluster) {
          Some(value) => value
          None => tail_name
        }
      }
    let head_leader =
      if head_cluster == "" {
        head_name
      } else {
        match cluster_leaders.get(head_cluster) {
          Some(value) => value
          None => head_name
        }
      }
    let tail_local = match local_ranks.get(tail_name) {
      Some(value) => value
      None => 0
    }
    let head_local = match local_ranks.get(head_name) {
      Some(value) => value
      None => 0
    }
    let offset = minlen + tail_local - head_local
    let tail_slack_len = if offset > 0 { 0 } else { -offset }
    let head_slack_len = if offset > 0 { offset } else { 0 }
    let slack_name = "_mbt_rank_slack_\{slack_id}"
    slack_id = slack_id + 1
    let slack_idx = @network_simplex.add_node(
      rank_graph,
      slack_name,
      kind=@network_simplex.NodeKind::Slack,
    )
    let tail_idx = match rank_index.get(tail_leader) {
      Some(value) => value
      None => continue
    }
    let head_idx = match rank_index.get(head_leader) {
      Some(value) => value
      None => continue
    }
    let _ = @network_simplex.add_edge(
      rank_graph,
      slack_idx,
      tail_idx,
      tail_slack_len,
      weight * back_weight_scale,
    )
    let _ = @network_simplex.add_edge(
      rank_graph,
      slack_idx,
      head_idx,
      head_slack_len,
      weight,
    )
  }
  let direct_oriented = orient_edges_for_names(
    rank_names,
    direct_tail,
    direct_head,
    direct_active,
  )
  let direct_tail_final = direct_oriented.tail
  let direct_head_final = direct_oriented.head
  let merged_edges : Map[String, LeaderRankEdge] = Map::new()
  for i in 0..<direct_tail_final.length() {
    let tail_name = direct_tail_final[i]
    let head_name = direct_head_final[i]
    if tail_name == head_name {
      continue
    }
    let tail_idx = match rank_index.get(tail_name) {
      Some(value) => value
      None => continue
    }
    let head_idx = match rank_index.get(head_name) {
      Some(value) => value
      None => continue
    }
    let minlen = direct_minlen[i]
    let weight = direct_weight[i]
    let key = "\{tail_idx}:\{head_idx}"
    match merged_edges.get(key) {
      Some(entry) => {
        let next_minlen =
          if minlen > entry.minlen { minlen } else { entry.minlen }
        merged_edges[key] = {
          tail_idx,
          head_idx,
          minlen: next_minlen,
          weight: entry.weight + weight,
        }
      }
      None => merged_edges[key] = { tail_idx, head_idx, minlen, weight }
    }
  }
  for _key, entry in merged_edges {
    let _ = @network_simplex.add_edge(
      rank_graph,
      entry.tail_idx,
      entry.head_idx,
      entry.minlen,
      entry.weight,
    )
  }
  let _ = @network_simplex.network_simplex_pre_balance(rank_graph, 0x7fffffff)
  let leader_ranks : Map[String, Int] = Map::new()
  for name, idx in rank_index {
    leader_ranks[name] = @network_simplex.node_rank(rank_graph, idx)
  }
  leader_ranks
}
