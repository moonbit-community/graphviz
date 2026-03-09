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

///|
/// Graphviz parity: clustered rank projection combines leader/global ranks with
/// per-cluster local offsets, then normalizes to zero minimum rank.
/// Do not change behavior without updating fixtures/tests.
pub fn project_clustered_node_ranks(
  nodes : Array[@cgraph.Node],
  node_cluster : Map[String, String],
  cluster_leaders : Map[String, String],
  local_ranks : Map[String, Int],
  leader_ranks : Map[String, Int],
) -> Map[String, Int] {
  let ranks : Map[String, Int] = Map::new()
  let mut min_rank = 0
  let mut seen = false
  for node in nodes {
    let name = node.name()
    let cluster = match node_cluster.get(name) {
      Some(value) => value
      None => ""
    }
    let base_rank = if cluster == "" {
      match leader_ranks.get(name) {
        Some(value) => value
        None => 0
      }
    } else {
      let leader = match cluster_leaders.get(cluster) {
        Some(value) => value
        None => name
      }
      let leader_rank = match leader_ranks.get(leader) {
        Some(value) => value
        None => 0
      }
      let local_rank = match local_ranks.get(name) {
        Some(value) => value
        None => 0
      }
      leader_rank + local_rank
    }
    if !seen {
      min_rank = base_rank
      seen = true
    } else if base_rank < min_rank {
      min_rank = base_rank
    }
    ranks[name] = base_rank
  }
  for name, rank in ranks {
    ranks[name] = rank - min_rank
  }
  ranks
}

///|
/// Graphviz parity: clustered path applies rank-set representative collapse and
/// min/max/source/sink extrema post-processing after projection.
/// Do not change behavior without updating fixtures/tests.
pub fn apply_clustered_rank_postprocessing(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  ranks : Map[String, Int],
) -> Map[String, Int] {
  let rank_same_reps = @rank_constraints.build_rank_same_reps(source, nodes)
  let rep_ranks : Map[String, Int] = Map::new()
  for name, rank in ranks {
    let rep = match rank_same_reps.get(name) {
      Some(value) => value
      None => name
    }
    if name == rep {
      rep_ranks[rep] = rank
    }
  }
  for name, rank in ranks {
    let rep = match rank_same_reps.get(name) {
      Some(value) => value
      None => name
    }
    let rep_rank = match rep_ranks.get(rep) {
      Some(value) => value
      None => rank
    }
    ranks[name] = rep_rank
  }
  let min_nodes : Map[String, Bool] = Map::new()
  let max_nodes : Map[String, Bool] = Map::new()
  @solver.collect_rank_extremes(source, min_nodes, max_nodes)
  @solver.apply_rank_extremes(ranks, min_nodes, max_nodes)
  ranks
}
