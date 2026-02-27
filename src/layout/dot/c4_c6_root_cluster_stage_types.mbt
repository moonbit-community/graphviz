///|
/// Stage C Phase C4/C6 split: root-cluster and finalize
/// stage type definitions for clustered ordering flow.

///|
priv struct OrderRootClusterStageData {
  order_groups_for_mincross : Map[Int, Array[String]]
  ordered : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
/// Graphviz parity: clustered finalize-stage input payload keeps rank/group,
/// cluster keys/skeleton, order sizes, and vnode ordering fields unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterFinalizeStageInputs {
  order_rank_keys : Array[Int]
  order_groups_for_mincross : Map[Int, Array[String]]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  order_sizes_out : Map[String, NodeSize]
  ordered : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
  creation_order : Array[String]
}

///|
/// Graphviz parity: finalize-pass dispatch context keeps clustered finalize
/// runtime payload ordering unchanged across cluster-rank/ReMincross phases.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusterFinalizePassDispatchContext {
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
/// Graphviz parity: final group cleanup dispatch context keeps cluster cleanup
/// branch payload ordering unchanged before clustered ReMincross dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct FinalizeOrderGroupsDispatchContext {
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
  flat_rank_constraints : Map[String, Bool]
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
}

///|
/// Graphviz parity: root+cluster build_ranks stage input payload keeps root
/// reorder/materialized artifacts and vnode groups unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterBuildRanksStageInputs {
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
/// Graphviz parity: root+cluster build_ranks stage context keeps runtime
/// dispatch payload ordering unchanged across root-reorder/finalize phases.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterBuildRanksStageContext {
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
}

///|
/// Graphviz parity: root+cluster root-reorder dispatch context keeps seeded
/// build_ranks and root ReMincross payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct RootClusterRootReorderContext {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  cluster_meta : ClusterMetadata
  vnode_order_keys_for_ordering : Map[String, Double]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
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
  flat_rank_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: root ReMincross rank-reorder finalize dispatch context
/// keeps finalize-phase arguments in Graphviz ordering before tuple unpack.
/// Do not change behavior without updating fixtures/tests.
priv struct RootMincrossRankReorderFinalizeDispatchContext {
  order_groups_for_mincross : Map[Int, Array[String]]
  order_cluster_keys : Map[String, String]
  cluster_meta : ClusterMetadata
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_cluster_skeleton : Map[String, Bool]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}
