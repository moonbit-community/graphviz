///|
/// Stage C Phase C6 split: cluster-rank finalize, finalize-order group cleanup,
/// and nlist creation helpers for Stage C outputs.

///|
/// Graphviz parity: clustered finalize groups keep cleaned real-node ranks,
/// optionally apply cluster-rank bucket reorder, then apply local-cluster
/// ordering before final ReMincross.
fn build_clustered_finalize_groups(
  cleaned_groups : Map[Int, Array[String]],
  cluster_rank_order : Map[Int, Map[String, Int]],
  cluster_meta : ClusterMetadata,
  local_cluster_order : Map[String, Int],
) -> Map[Int, Array[String]] {
  let should_skip_cluster_rank_reorder =
    @ordering.should_skip_cluster_rank_bucket_reorder(
      cluster_rank_order,
      cleaned_groups,
      cluster_meta.cluster_keys,
    )
  let final_groups =
    if should_skip_cluster_rank_reorder {
      cleaned_groups
    } else {
      @ordering.reorder_groups_by_cluster(
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
  final_groups
}

///|
/// Graphviz parity: final group cleanup keeps only real nodes, applies
/// cluster-rank/local-cluster bucket ordering, then runs clustered ReMincross
/// refinement before returning final groups.
/// Do not change behavior without updating fixtures/tests.
fn finalize_order_groups(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : OrderRootClusterData,
  cluster_rank_order : Map[Int, Map[String, Int]],
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let reorder_context = pre_root_stage.reorder_context
  let cleaned_groups =
    @ordering.collect_real_only_rank_groups(
      reorder_context.order_rank_keys,
      root_cluster_stage.ordered,
      runtime_context.real_nodes,
    )
  if reorder_setup.order_with_clusters {
    let final_groups =
      build_clustered_finalize_groups(
        cleaned_groups,
        cluster_rank_order,
        dispatch_context.cluster_meta,
        runtime_context.local_cluster_order,
      )
    let remincross_output =
      @ordering.run_remincross_pass(
        {
          ratio: dispatch_context.graph.get_attr("ratio").unwrap_or_default(),
          edges: dispatch_context.edges,
          edge_tail: dispatch_context.edge_tail,
          edge_head: dispatch_context.edge_head,
          edge_reversed: dispatch_context.edge_reversed,
          edge_tail_port_x: dispatch_context.edge_port_data.edge_tail_port_x,
          edge_head_port_x: dispatch_context.edge_port_data.edge_head_port_x,
          edge_tail_port_order: dispatch_context.edge_port_data.edge_tail_port_order,
          edge_head_port_order: dispatch_context.edge_port_data.edge_head_port_order,
          ranks: dispatch_context.ranks,
          order_with_vnodes: reorder_setup.order_with_vnodes,
          order_with_clusters: true,
          creation_order: reorder_context.creation_order,
          edges_by_tail: class2_data.edges_by_tail,
          cluster_order: dispatch_context.cluster_meta.cluster_order,
          cluster_keys: dispatch_context.cluster_meta.cluster_keys,
          intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
          cluster_parents: dispatch_context.cluster_meta.cluster_parents,
          cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
          cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
          cluster_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
          rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
          rank_same_order: dispatch_context.cluster_meta.rank_same_order,
          edge_vnodes: runtime_context.vnode_info.edge_vnodes,
          vnode_ranks: runtime_context.vnode_info.vnode_ranks,
          vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
          vnode_sizes: runtime_context.vnode_info.vnode_sizes,
          order_sizes: dispatch_context.order_sizes,
          rank_same_constraints: runtime_context.rank_same_constraints,
          ordered_with_vnodes: root_cluster_stage.ordered_with_vnodes,
          base_groups: final_groups,
          real_nodes: runtime_context.real_nodes,
          root_tail_order_override: remincross_root_tail_order_override_snapshot.val,
          root_cluster: dispatch_context.graph.name().unwrap_or("__root__"),
          graphviz_flip: reorder_setup.graphviz_flip,
          nodesep_pt: dispatch_context.nodesep_pt,
          has_edge_labels: dispatch_context.has_edge_labels,
          port_order_positions: dispatch_context.port_order_positions,
          port_order_contrib: dispatch_context.port_order_contrib,
        },
        build_vnode_order_keys,
        capture_inputs =>
          capture_remincross_snapshot(
            capture_inputs.rem_rank_keys,
            capture_inputs.rem_groups,
            capture_inputs.rem_edges_out,
            capture_inputs.rem_edge_tail_out,
            capture_inputs.rem_edge_head_out,
            capture_inputs.rem_edge_tail_port_x,
            capture_inputs.rem_edge_head_port_x,
            capture_inputs.rem_edge_tail_port_order,
            capture_inputs.rem_edge_head_port_order,
            capture_inputs.rem_cluster_keys,
          ),
        reorder_inputs =>
          reorder_rank_groups(
            reorder_inputs.rem_rank_keys,
            reorder_inputs.rem_groups,
            reorder_inputs.rem_edges_out,
            reorder_inputs.rem_edge_tail_out,
            reorder_inputs.rem_edge_head_out,
            reorder_inputs.rem_edge_tail_port_x,
            reorder_inputs.rem_edge_head_port_x,
            reorder_inputs.rem_edge_tail_port_order,
            reorder_inputs.rem_edge_head_port_order,
            reorder_inputs.rem_parents,
            reorder_inputs.rem_children,
            reorder_inputs.rem_cluster_keys,
            reorder_inputs.rank_same_groups,
            reorder_inputs.rank_same_order,
            reorder_inputs.rem_edge_order,
            reorder_inputs.rem_node_order,
            reorder_inputs.rem_sizes,
            reorder_inputs.nodesep_pt,
            reorder_inputs.has_edge_labels,
            reorder_inputs.port_order_positions,
            reorder_inputs.port_order_contrib,
            Map::new(),
            Map::new(),
            reorder_inputs.rem_flat_constraints,
            graphviz_flip=reorder_inputs.graphviz_flip,
            // Graphviz parity: ReMincross counts parallel chain segments once
            // with summed xpenalty before startpass=2 transposition.
            coalesce_parallel_edges=true,
            startpass=2,
            remincross_mode=true,
          ),
      )
    {
      ordered_groups: remincross_output.ordered_groups,
      ordered_with_vnodes: remincross_output.ordered_with_vnodes,
    }
  } else {
    {
      ordered_groups: cleaned_groups,
      ordered_with_vnodes: root_cluster_stage.ordered_with_vnodes,
    }
  }
}
