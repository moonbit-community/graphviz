///|
/// Ordering domain: clustered ReMincross pass orchestration helpers used by
/// Stage C finalize flow before output group cleanup.

///|
/// Graphviz parity: clustered ReMincross build context keeps finalize-stage
/// snapshots unchanged and is paired with per-branch base groups at call time.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ReMincrossPassBuildContext {
  ratio : String
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  ranks : Map[String, Int]
  order_with_vnodes : Bool
  creation_order : Array[String]
  edges_by_tail : Map[String, Array[Int]]
  cluster_order : Array[String]
  cluster_keys : Map[String, String]
  intercluster_keys : Map[String, String]
  cluster_parents : Map[String, String?]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_flat_constraints : Map[String, Bool]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  edge_vnodes : Map[String, Array[String]]
  vnode_ranks : Map[String, Int]
  vnodes_by_rank : Map[Int, Array[String]]
  vnode_sizes : Map[String, @shared.NodeSize]
  order_sizes : Map[String, @shared.NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  real_nodes : Map[String, Bool]
  root_tail_order_override : Array[String]?
  root_cluster : String
  graphviz_flip : Bool
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Graphviz parity: clustered ReMincross pass output keeps cleaned real-node
/// groups and vnode-inclusive groups after startpass=2 cleanup reorder.
pub(all) struct ReMincrossPassOutput {
  ordered_groups : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
/// Graphviz parity: Stage C finalize payload keeps root-cleanup sources,
/// cluster-rank replay maps, and ReMincross context snapshots unchanged.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct ClusteredFinalizeInputs {
  order_with_clusters : Bool
  order_rank_keys : Array[Int]
  ordered : Map[Int, Array[String]]
  cluster_rank_order : Map[Int, Map[String, Int]]
  remincross_context : ReMincrossPassBuildContext
}

///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
pub fn run_clustered_finalize_order_groups(
  inputs : ClusteredFinalizeInputs,
  apply_local_cluster_order : (Map[Int, Array[String]]) -> Unit,
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
  capture_call : (ReMincrossCleanupCaptureInputs) -> Unit,
  reorder_call : (ReMincrossCleanupReorderInputs) -> Map[Int, Array[String]],
) -> ReMincrossPassOutput {
  let cleaned_groups =
    collect_real_only_rank_groups(
      inputs.order_rank_keys,
      inputs.ordered,
      inputs.remincross_context.real_nodes,
    )
  if !inputs.order_with_clusters {
    return {
      ordered_groups: cleaned_groups,
      ordered_with_vnodes: inputs.remincross_context.ordered_with_vnodes,
    }
  }
  let final_groups =
    build_clustered_finalize_groups(
      cleaned_groups,
      inputs.cluster_rank_order,
      inputs.remincross_context.cluster_keys,
      apply_local_cluster_order,
    )
  run_remincross_pass(
    inputs.remincross_context,
    final_groups,
    build_vnode_order_keys,
    capture_call,
    reorder_call,
  )
}

///|
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
pub fn run_remincross_pass(
  context : ReMincrossPassBuildContext,
  base_groups : Map[Int, Array[String]],
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
  capture_call : (ReMincrossCleanupCaptureInputs) -> Unit,
  reorder_call : (ReMincrossCleanupReorderInputs) -> Map[Int, Array[String]],
) -> ReMincrossPassOutput {
  let rem_groups =
    build_remincross_groups(
      {
        ratio: context.ratio,
        cluster_order: context.cluster_order,
        ordered_with_vnodes: context.ordered_with_vnodes,
        cluster_keys: context.cluster_keys,
        vnode_group_inputs: {
          final_groups: base_groups,
          order_with_vnodes: context.order_with_vnodes,
          edges: context.edges,
          edge_tail: context.edge_tail,
          edge_head: context.edge_head,
          edge_reversed: context.edge_reversed,
          ranks: context.ranks,
          intercluster_keys: context.intercluster_keys,
          cluster_parents: context.cluster_parents,
          cluster_min_rank: context.cluster_min_rank,
          cluster_max_rank: context.cluster_max_rank,
          edge_vnodes: context.edge_vnodes,
          vnode_ranks: context.vnode_ranks,
          vnodes_by_rank: context.vnodes_by_rank,
        },
      },
      build_vnode_order_keys,
    )
  let rem_rank_keys = collect_rank_keys(rem_groups)
  if rem_rank_keys.length() <= 1 {
    {
      ordered_groups: base_groups,
      ordered_with_vnodes: context.ordered_with_vnodes,
    }
  } else {
    // Graphviz parity: clustered ReMincross multi-rank branch materializes
    // remapped edges and executes clustered cleanup reorder in startpass=2.
    let materialized_inputs =
      build_remincross_materialized_inputs(
        {
          rem_rank_keys,
          rem_groups,
          creation_order: context.creation_order,
          edges: context.edges,
          edge_tail: context.edge_tail,
          edge_head: context.edge_head,
          edge_tail_port_x: context.edge_tail_port_x,
          edge_head_port_x: context.edge_head_port_x,
          edge_tail_port_order: context.edge_tail_port_order,
          edge_head_port_order: context.edge_head_port_order,
          ranks: context.ranks,
          edge_vnodes: context.edge_vnodes,
          order_with_vnodes: context.order_with_vnodes,
          intercluster_keys: context.intercluster_keys,
          cluster_order: context.cluster_order,
          order_with_clusters: true,
          edges_by_tail: context.edges_by_tail,
          root_tail_order_override: context.root_tail_order_override,
          root_cluster: context.root_cluster,
          cluster_parents: context.cluster_parents,
          order_sizes: context.order_sizes,
          vnode_sizes: context.vnode_sizes,
          cluster_flat_constraints: context.cluster_flat_constraints,
          rank_same_constraints: context.rank_same_constraints,
        },
      )
    let rem_ordered =
      run_remincross_cleanup(
        {
          rem_rank_keys,
          rem_groups,
          materialized_inputs,
          rank_same_groups: context.rank_same_groups,
          rank_same_order: context.rank_same_order,
          nodesep_pt: context.nodesep_pt,
          has_edge_labels: context.has_edge_labels,
          port_order_positions: context.port_order_positions,
          port_order_contrib: context.port_order_contrib,
          graphviz_flip: context.graphviz_flip,
        },
        capture_call,
        reorder_call,
      )
    let rem_cleaned =
      collect_real_only_rank_groups(
        rem_rank_keys,
        rem_ordered,
        context.real_nodes,
      )
    {
      ordered_groups: rem_cleaned,
      ordered_with_vnodes: rem_ordered,
    }
  }
}
