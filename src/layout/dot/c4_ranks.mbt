///|
/// Stage C Phase C4/C6 split: root-cluster and finalize
/// stage type definitions for clustered ordering flow.

///|
priv struct OrderRootClusterData {
  order_groups_for_mincross : Map[Int, Array[String]]
  ordered : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
/// Graphviz parity: finalize-pass dispatch context keeps clustered finalize
/// runtime payload ordering unchanged across cluster-rank/ReMincross phases.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterFinalizeDispatchContext {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  graphviz_flip : Bool
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  nlist_order : Array[String]
  ranks : Map[String, Int]
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  skeleton_edge_creation : Array[(String, String)]
  root_edge_creation : Array[(String, String)]
  flat_rank_constraints : Map[String, Bool]
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  vnode_order_keys_for_ordering : Map[String, Double]
  real_nodes : Map[String, Bool]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  local_cluster_order : Map[String, Int]
  graph : @cgraph.Graph
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  edges_by_tail : Map[String, Array[Int]]
  order_sizes : Map[String, NodeSize]
  rank_same_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: root+cluster build_ranks stage input payload keeps root
/// reorder/materialized artifacts and vnode groups unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterBuildRanksInputs {
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  order_rank_keys : Array[Int]
  order_groups : Map[Int, Array[String]]
  order_ranks : Map[String, Int]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_edges_out_unmapped : Array[@cgraph.Edge]
  order_edge_tail_out_unmapped : Array[String]
  order_edge_head_out_unmapped : Array[String]
  order_edge_tail_port_x_unmapped : Array[Double]
  order_edge_head_port_x_unmapped : Array[Double]
  order_edge_tail_port_order_unmapped : Array[Double]
  order_edge_head_port_order_unmapped : Array[Double]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
/// Graphviz parity: root+cluster rank-reorder dispatch keeps runtime options,
/// rank/cluster metadata, and build_ranks snapshots in one context payload.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterRanksRunInputs {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  graph : @cgraph.Graph
  cluster_meta : ClusterMetadata
  vnode_order_keys_for_ordering : Map[String, Double]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
  flat_rank_constraints : Map[String, Bool]
  ranks : Map[String, Int]
  vnode_info : EdgeVnodeInfo
  build_ranks_inputs : RootClusterBuildRanksInputs
}

///|
/// Stage C Phase C4 split: root+cluster build_ranks
/// and reorder helpers for root-cluster arrangement.

///|
/// Graphviz parity: graphviz_flip root override replay is applied only when
/// flip mode is on and fixture override groups are present.
/// Do not change behavior without updating fixtures/tests.
fn apply_graphviz_flip_root_override(
  ordered : Map[Int, Array[String]],
  graphviz_flip : Bool,
  cluster_keys : Map[String, String],
) -> Map[Int, Array[String]] {
  if !graphviz_flip {
    return ordered
  }
  match root_mincross_groups_override.val {
    Some(override_groups) =>
      apply_root_groups_override(
        ordered,
        override_groups,
        cluster_keys,
        graphviz_flip,
      )
    None => ordered
  }
}

///|
/// Graphviz parity: root mincross reordering is followed by clustered
/// build_ranks application on the unmapped order graph before final cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_ranks(
  inputs : RootClusterRanksRunInputs,
) -> OrderRootClusterData {
  let build_ranks_inputs = inputs.build_ranks_inputs
  let seeded_groups =
    build_seeded_reorder_groups(
      build_ranks_inputs.order_rank_keys,
      build_ranks_inputs.order_groups,
      build_ranks_inputs.order_edge_tail_out,
      build_ranks_inputs.order_edge_head_out,
      build_ranks_inputs.order_ranks,
      build_ranks_inputs.order_node_order,
      build_ranks_inputs.order_cluster_keys,
      build_ranks_inputs.order_cluster_skeleton,
      build_ranks_inputs.order_flat_constraints,
      inputs.graphviz_flip,
      build_ranks_inputs.graphviz_out_neighbors,
      build_ranks_inputs.graphviz_in_neighbors,
      build_ranks_inputs.order_edges_out,
      build_ranks_inputs.order_edge_tail_port_x,
      build_ranks_inputs.order_edge_head_port_x,
      inputs.flat_rank_constraints,
    )
  let root_mincross_reorder_inputs : RootMincrossReorderInputs =
    {
      order_with_clusters: inputs.order_with_clusters,
      order_with_vnodes: inputs.order_with_vnodes,
      seeded_groups,
      order_rank_keys: build_ranks_inputs.order_rank_keys,
      order_ranks: build_ranks_inputs.order_ranks,
      order_edges_out: build_ranks_inputs.order_edges_out,
      order_edge_tail_out: build_ranks_inputs.order_edge_tail_out,
      order_edge_head_out: build_ranks_inputs.order_edge_head_out,
      order_edge_tail_port_x: build_ranks_inputs.order_edge_tail_port_x,
      order_edge_head_port_x: build_ranks_inputs.order_edge_head_port_x,
      order_edge_tail_port_order:
        build_ranks_inputs.order_edge_tail_port_order,
      order_edge_head_port_order:
        build_ranks_inputs.order_edge_head_port_order,
      order_cluster_keys: build_ranks_inputs.order_cluster_keys,
      order_cluster_skeleton: build_ranks_inputs.order_cluster_skeleton,
      cluster_meta: inputs.cluster_meta,
      vnode_order_keys_for_ordering: inputs.vnode_order_keys_for_ordering,
      order_node_order: build_ranks_inputs.order_node_order,
      order_sizes_out: build_ranks_inputs.order_sizes_out,
      nodesep_pt: inputs.nodesep_pt,
      has_edge_labels: inputs.has_edge_labels,
      port_order_positions: inputs.port_order_positions,
      port_order_contrib: inputs.port_order_contrib,
      order_flat_constraints: build_ranks_inputs.order_flat_constraints,
      graphviz_out_neighbors: build_ranks_inputs.graphviz_out_neighbors,
      graphviz_in_neighbors: build_ranks_inputs.graphviz_in_neighbors,
      graphviz_flip: inputs.graphviz_flip,
    }
  let root_mincross_reorder_output =
    run_root_mincross_reorder(root_mincross_reorder_inputs)
  let order_groups_for_mincross =
    root_mincross_reorder_output.order_groups_for_mincross
  let ordered =
    apply_graphviz_flip_root_override(
      root_mincross_reorder_output.ordered,
      inputs.graphviz_flip,
      inputs.cluster_meta.cluster_keys,
    )
  // Graphviz parity: clustered order pass runs cluster-local build_ranks on
  // the unmapped order graph, then stores vnode-inclusive rank groups for xpos.
  if inputs.order_with_clusters {
    reorder_by_cluster_ranks(
      inputs.graph,
      ordered,
      inputs.cluster_meta,
      build_ranks_inputs.order_node_order,
      build_ranks_inputs.order_edges_out_unmapped,
      build_ranks_inputs.order_edge_tail_out_unmapped,
      build_ranks_inputs.order_edge_head_out_unmapped,
      build_ranks_inputs.order_edge_tail_port_x_unmapped,
      build_ranks_inputs.order_edge_head_port_x_unmapped,
      build_ranks_inputs.order_edge_tail_port_order_unmapped,
      build_ranks_inputs.order_edge_head_port_order_unmapped,
      build_ranks_inputs.graphviz_out_neighbors,
      build_ranks_inputs.graphviz_in_neighbors,
      inputs.ranks,
      build_ranks_inputs.order_sizes_out,
      inputs.nodesep_pt,
      inputs.has_edge_labels,
      inputs.port_order_positions,
      inputs.port_order_contrib,
      inputs.vnode_info,
      inputs.order_with_vnodes,
    )
  }
  let next_ordered_with_vnodes =
    if !inputs.order_with_vnodes {
      build_ranks_inputs.ordered_with_vnodes
    } else {
      ordered
    }
  {
    order_groups_for_mincross,
    ordered,
    ordered_with_vnodes: next_ordered_with_vnodes,
  }
}
