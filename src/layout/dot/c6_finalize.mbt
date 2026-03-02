///|
/// Stage C Phase C6 split: cluster-rank finalize, finalize-order group cleanup,
/// and nlist creation helpers for Stage C outputs.

///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
priv struct FinalizeOrderGroupsInputs {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  cluster_rank_order : Map[Int, Map[String, Int]]
  cluster_meta : ClusterMetadata
  local_cluster_order : Map[String, Int]
  ordered_with_vnodes : Map[Int, Array[String]]
  graph : @cgraph.Graph
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  vnode_info : EdgeVnodeInfo
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  real_nodes : Map[String, Bool]
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_rank_keys : Array[Int]
  ordered : Map[Int, Array[String]]
}

///|
/// Graphviz parity: cluster-rank reorder is skipped when root reorder exposes
/// a single-cluster single-anchor shape (one cluster bucket globally and at
/// most one clustered node per rank).
fn should_skip_cluster_rank_bucket_reorder(
  cluster_rank_order : Map[Int, Map[String, Int]],
  cleaned_groups : Map[Int, Array[String]],
  cluster_keys : Map[String, String],
) -> Bool {
  let seen_clusters : Map[String, Bool] = Map::new()
  let mut has_single_cluster_rank_order_bucket = true
  for _rank, order_map in cluster_rank_order {
    if !has_single_cluster_rank_order_bucket {
      break
    }
    for cluster, _order in order_map {
      if cluster == "" {
        continue
      }
      seen_clusters[cluster] = true
      if seen_clusters.length() > 1 {
        has_single_cluster_rank_order_bucket = false
        break
      }
    }
  }
  if has_single_cluster_rank_order_bucket && seen_clusters.length() != 1 {
    return false
  }
  if !has_single_cluster_rank_order_bucket {
    return false
  }
  for _rank, names in cleaned_groups {
    let mut cluster_nodes = 0
    for name in names {
      if cluster_key_or_empty(cluster_keys, name) != "" {
        cluster_nodes = cluster_nodes + 1
        if cluster_nodes > 1 {
          return false
        }
      }
    }
  }
  true
}

///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
fn finalize_order_groups(
  inputs : FinalizeOrderGroupsInputs,
) -> OrderingDispatchOutput {
  let order_with_clusters = inputs.order_with_clusters
  let order_with_vnodes = inputs.order_with_vnodes
  let cluster_rank_order = inputs.cluster_rank_order
  let cluster_meta = inputs.cluster_meta
  let local_cluster_order = inputs.local_cluster_order
  let ordered_with_vnodes = inputs.ordered_with_vnodes
  let graph = inputs.graph
  let edges = inputs.edges
  let edge_tail = inputs.edge_tail
  let edge_head = inputs.edge_head
  let edge_reversed = inputs.edge_reversed
  let edge_tail_port_x = inputs.edge_tail_port_x
  let edge_head_port_x = inputs.edge_head_port_x
  let edge_tail_port_order = inputs.edge_tail_port_order
  let edge_head_port_order = inputs.edge_head_port_order
  let ranks = inputs.ranks
  let creation_order = inputs.creation_order
  let edges_by_tail = inputs.edges_by_tail
  let vnode_info = inputs.vnode_info
  let order_sizes = inputs.order_sizes
  let rank_same_constraints = inputs.rank_same_constraints
  let real_nodes = inputs.real_nodes
  let graphviz_flip = inputs.graphviz_flip
  let nodesep_pt = inputs.nodesep_pt
  let has_edge_labels = inputs.has_edge_labels
  let port_order_positions = inputs.port_order_positions
  let port_order_contrib = inputs.port_order_contrib
  let order_rank_keys = inputs.order_rank_keys
  let ordered = inputs.ordered
  let cleaned_groups =
    collect_real_only_rank_groups(
      order_rank_keys,
      ordered,
      real_nodes,
    )
  if order_with_clusters {
    let should_skip_cluster_rank_reorder =
      should_skip_cluster_rank_bucket_reorder(
        cluster_rank_order,
        cleaned_groups,
        cluster_meta.cluster_keys,
      )
    let final_groups =
      if should_skip_cluster_rank_reorder {
        cleaned_groups
      } else {
        reorder_groups_by_cluster(
          cleaned_groups,
          cluster_rank_order,
          cluster_meta.cluster_keys,
        )
      }
    // Graphviz parity: order local subclusters within outer clusters by minrank/first order.
    reorder_by_local_cluster(
      final_groups,
      cluster_meta.cluster_keys,
      cluster_meta.intercluster_keys,
      local_cluster_order,
    )
    let remincross_context : ReMincrossDispatchContext = {
      graph,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      order_with_vnodes,
      order_with_clusters: true,
      creation_order,
      edges_by_tail,
      cluster_meta,
      vnode_info,
      order_sizes,
      rank_same_constraints,
      ordered_with_vnodes,
      base_groups: final_groups,
      real_nodes,
      graphviz_flip,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
    }
    run_remincross_pass(remincross_context)
  } else {
    {
      ordered_groups: cleaned_groups,
      ordered_with_vnodes,
    }
  }
}
