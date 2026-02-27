///|
/// Stage C Phase C4 split: root+cluster build_ranks
/// and reorder helpers for root-cluster arrangement.

///|
/// Graphviz parity: root+cluster build_ranks stage output preserves root
/// mincross groups and vnode-augmented ordering groups unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_build_ranks_stage_output(
  order_groups_for_mincross : Map[Int, Array[String]],
  ordered : Map[Int, Array[String]],
  next_ordered_with_vnodes : Map[Int, Array[String]],
) -> OrderRootClusterStageData {
  {
    order_groups_for_mincross,
    ordered,
    ordered_with_vnodes: next_ordered_with_vnodes,
  }
}

///|
/// Graphviz parity: root+cluster build_ranks stage seeds reorder groups via
/// Graphviz-style build_ranks pass before root ReMincross execution.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_seeded_groups(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  order_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  build_seeded_groups_for_order_reorder(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_flip,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    flat_rank_constraints,
  )
}

///|
/// Graphviz parity: root+cluster build_ranks stage runs root ReMincross on
/// seeded groups before any cluster-local build_ranks vnode remapping.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder_in_root_cluster_stage(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
  order_ranks : Map[String, Int],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_mincross_reorder(
    order_with_clusters,
    order_with_vnodes,
    seeded_groups,
    order_rank_keys,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_cluster_keys,
    order_cluster_skeleton,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    graphviz_flip,
  )
}

///|
/// Graphviz parity: root+cluster build_ranks stage applies clustered
/// build_ranks on unmapped order edges to update vnode-augmented ordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_ordered_with_vnodes(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  apply_cluster_build_ranks_and_track_vnodes(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
  )
}

///|
/// Graphviz parity: root+cluster root-reorder mincross phase forwards seeded
/// build_ranks groups into root ReMincross without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder_mincross_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  seeded_groups : Map[Int, Array[String]],
  order_rank_keys : Array[Int],
  order_ranks : Map[String, Int],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  graphviz_flip : Bool,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_mincross_reorder_in_root_cluster_stage(
    order_with_clusters,
    order_with_vnodes,
    seeded_groups,
    order_rank_keys,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    order_cluster_keys,
    order_cluster_skeleton,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: root+cluster root-reorder seed phase builds build_ranks
/// seeded groups from order graph inputs before root ReMincross dispatch.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder_seed_phase(
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_ranks : Map[String, Int],
  order_node_order : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_flip : Bool,
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> Map[Int, Array[String]] {
  build_root_and_cluster_seeded_groups(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_flip,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster seed dispatch reads typed root-reorder
/// context and forwards build_ranks seed inputs in Graphviz ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder_seed_phase_from_context(
  reorder_context : RootClusterRootReorderContext,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  run_root_and_cluster_root_reorder_seed_phase(
    order_rank_keys,
    order_groups,
    reorder_context.order_edge_tail_out,
    reorder_context.order_edge_head_out,
    reorder_context.order_ranks,
    reorder_context.order_node_order,
    reorder_context.order_cluster_keys,
    reorder_context.order_cluster_skeleton,
    reorder_context.order_flat_constraints,
    reorder_context.graphviz_flip,
    reorder_context.graphviz_out_neighbors,
    reorder_context.graphviz_in_neighbors,
    reorder_context.order_edges_out,
    reorder_context.order_edge_tail_port_x,
    reorder_context.order_edge_head_port_x,
    reorder_context.flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster output dispatch forwards seeded groups and
/// typed root-reorder context into root ReMincross unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder_output_phase_from_seeded_groups(
  reorder_context : RootClusterRootReorderContext,
  order_rank_keys : Array[Int],
  seeded_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_and_cluster_root_reorder_mincross_phase(
    reorder_context.order_with_clusters,
    reorder_context.order_with_vnodes,
    seeded_groups,
    order_rank_keys,
    reorder_context.order_ranks,
    reorder_context.order_edges_out,
    reorder_context.order_edge_tail_out,
    reorder_context.order_edge_head_out,
    reorder_context.order_edge_tail_port_x,
    reorder_context.order_edge_head_port_x,
    reorder_context.order_edge_tail_port_order,
    reorder_context.order_edge_head_port_order,
    reorder_context.order_cluster_keys,
    reorder_context.order_cluster_skeleton,
    reorder_context.cluster_meta,
    reorder_context.vnode_order_keys_for_ordering,
    reorder_context.order_node_order,
    reorder_context.order_sizes_out,
    reorder_context.nodesep_pt,
    reorder_context.has_edge_labels,
    reorder_context.port_order_positions,
    reorder_context.port_order_contrib,
    reorder_context.order_flat_constraints,
    reorder_context.graphviz_out_neighbors,
    reorder_context.graphviz_in_neighbors,
    reorder_context.graphviz_flip,
  )
}


///|
/// Graphviz parity: root+cluster stage seeds build_ranks groups then runs
/// root ReMincross before any cluster-local unmapped-edge build_ranks pass.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_root_reorder(
  reorder_context : RootClusterRootReorderContext,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let seeded_groups =
    run_root_and_cluster_root_reorder_seed_phase_from_context(
      reorder_context,
      order_rank_keys,
      order_groups,
    )
  run_root_and_cluster_root_reorder_output_phase_from_seeded_groups(
    reorder_context,
    order_rank_keys,
    seeded_groups,
  )
}

///|
/// Graphviz parity: clustered build_ranks stage derives the vnode-inclusive
/// ordering from the root-reordered groups on the unmapped order graph.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_next_ordered_with_vnodes(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> Map[Int, Array[String]] {
  build_root_and_cluster_ordered_with_vnodes(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
  )
}

///|
/// Graphviz parity: clustered build_ranks stage first runs root-level mincross
/// reorder on the order graph before local-cluster build_ranks application.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_root_reorder_result(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_context : RootClusterRootReorderContext = {
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    order_ranks,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    flat_rank_constraints,
  }
  run_root_and_cluster_root_reorder(
    reorder_context,
    order_rank_keys,
    order_groups,
  )
}

///|
/// Graphviz parity: post-root-reorder stage applies clustered build_ranks on
/// unmapped order edges and returns Graphviz tuple-ordered stage output.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_stage_output_after_root_reorder(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  order_groups_for_mincross : Map[Int, Array[String]],
) -> OrderRootClusterStageData {
  let ordered =
    if graphviz_flip {
      match root_mincross_groups_override.val {
        Some(override_groups) =>
          apply_root_rank_groups_override(
            ordered,
            override_groups,
            cluster_meta.cluster_keys,
            graphviz_flip,
          )
        None => ordered
      }
    } else {
      ordered
    }
  dot_trace_groups("ordered_after_root_merge", ordered)
  let next_ordered_with_vnodes =
    build_root_and_cluster_next_ordered_with_vnodes(
      order_with_clusters,
      order_with_vnodes,
      graph,
      ordered,
      cluster_meta,
      order_node_order,
      order_edges_out_unmapped,
      order_edge_tail_out_unmapped,
      order_edge_head_out_unmapped,
      order_edge_tail_port_x_unmapped,
      order_edge_head_port_x_unmapped,
      order_edge_tail_port_order_unmapped,
      order_edge_head_port_order_unmapped,
      graphviz_out_neighbors,
      graphviz_in_neighbors,
      ranks,
      order_sizes_out,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      vnode_info,
      graphviz_flip,
      ordered_with_vnodes,
    )
  dot_trace_groups("ordered_before_clean", ordered)
  build_root_and_cluster_build_ranks_stage_output(
    order_groups_for_mincross,
    ordered,
    next_ordered_with_vnodes,
  )
}


///|
/// Graphviz parity: root-reorder outputs are forwarded unchanged into the
/// unmapped-edge build_ranks stage before final root+cluster stage output.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_from_root_reorder_result(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  order_groups_for_mincross : Map[Int, Array[String]],
) -> OrderRootClusterStageData {
  build_root_and_cluster_stage_output_after_root_reorder(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
    order_groups_for_mincross,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks stage computes root-level
/// mincross reorder outputs before unmapped-edge build_ranks forwarding.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_root_reorder_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  build_root_and_cluster_root_reorder_result(
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    order_rank_keys,
    order_groups,
    order_ranks,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks finalize phase applies clustered
/// unmapped-edge build_ranks and forwards root-reorder outputs unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_finalize_phase(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  ordered : Map[Int, Array[String]],
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  order_groups_for_mincross : Map[Int, Array[String]],
) -> OrderRootClusterStageData {
  run_root_and_cluster_build_ranks_stage_from_root_reorder_result(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
    order_groups_for_mincross,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks finalize dispatch reads
/// root-reorder tuple and forwards values in Graphviz argument order.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_finalize_phase_from_root_reorder_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  root_reorder_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> OrderRootClusterStageData {
  let (order_groups_for_mincross, ordered) = root_reorder_output
  run_root_and_cluster_build_ranks_stage_finalize_phase(
    order_with_clusters,
    order_with_vnodes,
    graph,
    ordered,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
    order_groups_for_mincross,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks root-reorder dispatch reads
/// stage inputs and forwards them in Graphviz phase-call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_root_reorder_phase_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  order_node_order : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  order_rank_keys : Array[Int],
  order_groups : Map[Int, Array[String]],
  order_ranks : Map[String, Int],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  order_flat_constraints : Map[String, Bool],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  order_edges_out : Array[@cgraph.Edge],
  order_edge_tail_out : Array[String],
  order_edge_head_out : Array[String],
  order_edge_tail_port_x : Array[Double],
  order_edge_head_port_x : Array[Double],
  order_edge_tail_port_order : Array[Double],
  order_edge_head_port_order : Array[Double],
  flat_rank_constraints : Map[String, Bool],
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_and_cluster_build_ranks_stage_root_reorder_phase(
    order_with_clusters,
    order_with_vnodes,
    cluster_meta,
    vnode_order_keys_for_ordering,
    order_node_order,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    order_rank_keys,
    order_groups,
    order_ranks,
    order_cluster_keys,
    order_cluster_skeleton,
    order_flat_constraints,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
    flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks finalize-stage output dispatch
/// reads root-reorder output and forwards payload in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_finalize_phase_output(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  order_node_order : Map[String, Int],
  order_edges_out_unmapped : Array[@cgraph.Edge],
  order_edge_tail_out_unmapped : Array[String],
  order_edge_head_out_unmapped : Array[String],
  order_edge_tail_port_x_unmapped : Array[Double],
  order_edge_head_port_x_unmapped : Array[Double],
  order_edge_tail_port_order_unmapped : Array[Double],
  order_edge_head_port_order_unmapped : Array[Double],
  graphviz_out_neighbors : Map[String, Array[String]],
  graphviz_in_neighbors : Map[String, Array[String]],
  ranks : Map[String, Int],
  order_sizes_out : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  vnode_info : EdgeVnodeInfo,
  graphviz_flip : Bool,
  ordered_with_vnodes : Map[Int, Array[String]],
  root_reorder_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> OrderRootClusterStageData {
  run_root_and_cluster_build_ranks_stage_finalize_phase_from_root_reorder_output(
    order_with_clusters,
    order_with_vnodes,
    graph,
    cluster_meta,
    order_node_order,
    order_edges_out_unmapped,
    order_edge_tail_out_unmapped,
    order_edge_head_out_unmapped,
    order_edge_tail_port_x_unmapped,
    order_edge_head_port_x_unmapped,
    order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped,
    graphviz_out_neighbors,
    graphviz_in_neighbors,
    ranks,
    order_sizes_out,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    vnode_info,
    graphviz_flip,
    ordered_with_vnodes,
    root_reorder_output,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks stage context builder preserves
/// runtime dispatch field ordering before phase forwarding.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_build_ranks_stage_context(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  flat_rank_constraints : Map[String, Bool],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
) -> RootClusterBuildRanksStageContext {
  {
    order_with_clusters,
    order_with_vnodes,
    graph,
    cluster_meta,
    vnode_order_keys_for_ordering,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    graphviz_flip,
    flat_rank_constraints,
    ranks,
    vnode_info,
  }
}


///|
/// Graphviz parity: root+cluster build_ranks root-reorder phase dispatch reads
/// typed stage context and stage inputs in Graphviz call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_root_reorder_phase_output_from_context(
  stage_context : RootClusterBuildRanksStageContext,
  stage_inputs : RootClusterBuildRanksStageInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  run_root_and_cluster_build_ranks_stage_root_reorder_phase_output(
    stage_context.order_with_clusters,
    stage_context.order_with_vnodes,
    stage_context.cluster_meta,
    stage_context.vnode_order_keys_for_ordering,
    stage_inputs.order_node_order,
    stage_inputs.order_sizes_out,
    stage_context.nodesep_pt,
    stage_context.has_edge_labels,
    stage_context.port_order_positions,
    stage_context.port_order_contrib,
    stage_context.graphviz_flip,
    stage_inputs.order_rank_keys,
    stage_inputs.order_groups,
    stage_inputs.order_ranks,
    stage_inputs.order_cluster_keys,
    stage_inputs.order_cluster_skeleton,
    stage_inputs.order_flat_constraints,
    stage_inputs.graphviz_out_neighbors,
    stage_inputs.graphviz_in_neighbors,
    stage_inputs.order_edges_out,
    stage_inputs.order_edge_tail_out,
    stage_inputs.order_edge_head_out,
    stage_inputs.order_edge_tail_port_x,
    stage_inputs.order_edge_head_port_x,
    stage_inputs.order_edge_tail_port_order,
    stage_inputs.order_edge_head_port_order,
    stage_context.flat_rank_constraints,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks finalize-phase dispatch reads
/// typed stage context and root-reorder output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_finalize_phase_output_from_context(
  stage_context : RootClusterBuildRanksStageContext,
  stage_inputs : RootClusterBuildRanksStageInputs,
  root_reorder_output : (Map[Int, Array[String]], Map[Int, Array[String]]),
) -> OrderRootClusterStageData {
  run_root_and_cluster_build_ranks_stage_finalize_phase_output(
    stage_context.order_with_clusters,
    stage_context.order_with_vnodes,
    stage_context.graph,
    stage_context.cluster_meta,
    stage_inputs.order_node_order,
    stage_inputs.order_edges_out_unmapped,
    stage_inputs.order_edge_tail_out_unmapped,
    stage_inputs.order_edge_head_out_unmapped,
    stage_inputs.order_edge_tail_port_x_unmapped,
    stage_inputs.order_edge_head_port_x_unmapped,
    stage_inputs.order_edge_tail_port_order_unmapped,
    stage_inputs.order_edge_head_port_order_unmapped,
    stage_inputs.graphviz_out_neighbors,
    stage_inputs.graphviz_in_neighbors,
    stage_context.ranks,
    stage_inputs.order_sizes_out,
    stage_context.nodesep_pt,
    stage_context.has_edge_labels,
    stage_context.port_order_positions,
    stage_context.port_order_contrib,
    stage_context.vnode_info,
    stage_context.graphviz_flip,
    stage_inputs.ordered_with_vnodes,
    root_reorder_output,
  )
}


///|
/// Graphviz parity: root mincross reordering is followed by clustered
/// build_ranks application on the unmapped order graph before final cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graph : @cgraph.Graph,
  cluster_meta : ClusterMetadata,
  vnode_order_keys_for_ordering : Map[String, Double],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  graphviz_flip : Bool,
  flat_rank_constraints : Map[String, Bool],
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  stage_inputs : RootClusterBuildRanksStageInputs,
) -> OrderRootClusterStageData {
  let stage_context =
    build_root_and_cluster_build_ranks_stage_context(
      order_with_clusters,
      order_with_vnodes,
      graph,
      cluster_meta,
      vnode_order_keys_for_ordering,
      nodesep_pt,
      has_edge_labels,
      port_order_positions,
      port_order_contrib,
      graphviz_flip,
      flat_rank_constraints,
      ranks,
      vnode_info,
    )
  let root_reorder_output =
    run_root_and_cluster_build_ranks_stage_root_reorder_phase_output_from_context(
      stage_context,
      stage_inputs,
    )
  run_root_and_cluster_build_ranks_stage_finalize_phase_output_from_context(
    stage_context,
    stage_inputs,
    root_reorder_output,
  )
}

