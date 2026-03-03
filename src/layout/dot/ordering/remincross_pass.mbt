///|
/// Ordering domain: clustered ReMincross pass orchestration helpers used by
/// Stage C finalize flow before output group cleanup.

///|
/// Graphviz parity: clustered ReMincross pass inputs capture seeded/vnode
/// group context plus rematerialized startpass=2 cleanup context snapshots.
pub(all) struct ReMincrossPassInputs {
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
  order_with_clusters : Bool
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
  vnode_sizes : Map[String, NodeSize]
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
  ordered_with_vnodes : Map[Int, Array[String]]
  base_groups : Map[Int, Array[String]]
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
/// Graphviz parity: clustered ReMincross pass runs on real-node groups plus
/// edge vnodes, then materializes/remaps edges and executes final startpass=2
/// reorder before dropping non-real nodes.
/// Do not change behavior without updating fixtures/tests.
pub fn run_remincross_pass(
  inputs : ReMincrossPassInputs,
  build_vnode_order_keys : (Array[@cgraph.Edge], Array[String], Array[String], Array[Bool], Map[String, Int], Map[String, Int], Map[String, String], Map[String, String?], Map[String, Array[String]], Map[String, Int]) -> Map[String, Double],
  capture_call : (ReMincrossCleanupCaptureInputs) -> Unit,
  reorder_call : (ReMincrossCleanupReorderInputs) -> Map[Int, Array[String]],
) -> ReMincrossPassOutput {
  let rem_groups =
    build_remincross_groups(
      {
        ratio: inputs.ratio,
        cluster_order: inputs.cluster_order,
        ordered_with_vnodes: inputs.ordered_with_vnodes,
        cluster_keys: inputs.cluster_keys,
        vnode_group_inputs: {
          final_groups: inputs.base_groups,
          order_with_vnodes: inputs.order_with_vnodes,
          edges: inputs.edges,
          edge_tail: inputs.edge_tail,
          edge_head: inputs.edge_head,
          edge_reversed: inputs.edge_reversed,
          ranks: inputs.ranks,
          intercluster_keys: inputs.intercluster_keys,
          cluster_parents: inputs.cluster_parents,
          cluster_min_rank: inputs.cluster_min_rank,
          cluster_max_rank: inputs.cluster_max_rank,
          edge_vnodes: inputs.edge_vnodes,
          vnode_ranks: inputs.vnode_ranks,
          vnodes_by_rank: inputs.vnodes_by_rank,
        },
      },
      build_vnode_order_keys,
    )
  let rem_rank_keys = collect_rank_keys(rem_groups)
  if rem_rank_keys.length() <= 1 {
    {
      ordered_groups: inputs.base_groups,
      ordered_with_vnodes: inputs.ordered_with_vnodes,
    }
  } else {
    // Graphviz parity: clustered ReMincross multi-rank branch materializes
    // remapped edges and executes clustered cleanup reorder in startpass=2.
    let materialized_inputs =
      build_remincross_materialized_inputs(
        {
          rem_rank_keys,
          rem_groups,
          creation_order: inputs.creation_order,
          edges: inputs.edges,
          edge_tail: inputs.edge_tail,
          edge_head: inputs.edge_head,
          edge_tail_port_x: inputs.edge_tail_port_x,
          edge_head_port_x: inputs.edge_head_port_x,
          edge_tail_port_order: inputs.edge_tail_port_order,
          edge_head_port_order: inputs.edge_head_port_order,
          ranks: inputs.ranks,
          edge_vnodes: inputs.edge_vnodes,
          order_with_vnodes: inputs.order_with_vnodes,
          intercluster_keys: inputs.intercluster_keys,
          cluster_order: inputs.cluster_order,
          order_with_clusters: inputs.order_with_clusters,
          edges_by_tail: inputs.edges_by_tail,
          root_tail_order_override: inputs.root_tail_order_override,
          root_cluster: inputs.root_cluster,
          cluster_parents: inputs.cluster_parents,
          order_sizes: inputs.order_sizes,
          vnode_sizes: inputs.vnode_sizes,
          cluster_flat_constraints: inputs.cluster_flat_constraints,
          rank_same_constraints: inputs.rank_same_constraints,
        },
      )
    let rem_ordered =
      run_remincross_cleanup(
        {
          rem_rank_keys,
          rem_groups,
          materialized_inputs,
          rank_same_groups: inputs.rank_same_groups,
          rank_same_order: inputs.rank_same_order,
          nodesep_pt: inputs.nodesep_pt,
          has_edge_labels: inputs.has_edge_labels,
          port_order_positions: inputs.port_order_positions,
          port_order_contrib: inputs.port_order_contrib,
          graphviz_flip: inputs.graphviz_flip,
        },
        capture_call,
        reorder_call,
      )
    let rem_cleaned =
      collect_real_only_rank_groups(
        rem_rank_keys,
        rem_ordered,
        inputs.real_nodes,
      )
    {
      ordered_groups: rem_cleaned,
      ordered_with_vnodes: rem_ordered,
    }
  }
}
