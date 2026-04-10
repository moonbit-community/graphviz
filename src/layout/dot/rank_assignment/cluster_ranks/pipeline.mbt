// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Graphviz parity: clustered rank assignment first computes top-level cluster
/// locals, then solves leader ranks, then projects/postprocesses final node
/// ranks in the same high-level order as rank.c.
/// Do not change behavior without updating fixtures/tests.
pub fn compute_clustered_ranks(
  source : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  has_edge_labels : Bool,
  back_weight_scale : Int,
  compute_recursive_ranks : (
    @cgraph.Graph,
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Bool,
    Int,
  ) -> Map[String, Int],
) -> Map[String, Int] {
  let top_cluster_data = collect_top_clusters(source)
  let cluster_graphs = top_cluster_data.cluster_graphs
  let top_clusters = top_cluster_data.top_clusters
  if top_clusters.length() == 0 {
    let acyclic_directions = @solver.acyclic_edge_directions_with_order(
      source, nodes, edges,
    )
    let tail = acyclic_directions.tail
    let head = acyclic_directions.head
    return @solver.compute_ranks_directed_base(
      source, nodes, edges, has_edge_labels, tail, head,
    )
  }
  let cluster_members = collect_cluster_members(cluster_graphs)
  let node_cluster = build_node_cluster_index(top_clusters, cluster_members)
  let local_cluster_ranks = compute_local_cluster_ranks_and_leaders(
    source,
    nodes,
    edges,
    top_clusters,
    cluster_graphs,
    cluster_members,
    (cluster_graph, cluster_nodes, cluster_edges) => {
      compute_recursive_ranks(
        cluster_graph, cluster_nodes, cluster_edges, has_edge_labels, back_weight_scale,
      )
    },
  )
  let local_ranks = local_cluster_ranks.local_ranks
  let cluster_leaders = local_cluster_ranks.cluster_leaders
  let leader_ranks = solve_clustered_leader_ranks(
    nodes,
    edges,
    node_cluster,
    cluster_leaders,
    local_ranks,
    has_edge_labels,
    back_weight_scale,
    (node_names, edge_tail, edge_head, edge_is_active) => {
      let directions = @solver.acyclic_edge_directions_for_names(
        node_names, edge_tail, edge_head, edge_is_active,
      )
      (directions.tail, directions.head, directions.reversed)
    },
  )
  let ranks = project_clustered_node_ranks(
    nodes, node_cluster, cluster_leaders, local_ranks, leader_ranks,
  )
  apply_clustered_rank_postprocessing(source, nodes, ranks)
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
