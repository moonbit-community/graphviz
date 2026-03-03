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
/// Stage C Phase C4 split: root+cluster build_ranks
/// and reorder helpers for root-cluster arrangement.

///|
/// Graphviz parity: root mincross reordering is followed by clustered
/// build_ranks application on the unmapped order graph before final cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_ranks(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> OrderRootClusterData {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  let reorder_context = pre_root_stage.reorder_context
  let materialized = pre_root_stage.materialized
  let seeded_groups =
    build_seeded_reorder_groups(
      reorder_context.order_rank_keys,
      pre_root_stage.order_groups,
      materialized.order_edge_tail_out,
      materialized.order_edge_head_out,
      reorder_context.order_ranks,
      reorder_context.order_node_order,
      pre_root_stage.order_cluster_keys,
      pre_root_stage.order_cluster_skeleton,
      materialized.order_flat_constraints,
      reorder_setup.graphviz_flip,
      materialized.graphviz_out_neighbors,
      materialized.graphviz_in_neighbors,
      materialized.order_edges_out,
      materialized.order_edge_tail_port_x,
      materialized.order_edge_head_port_x,
      reorder_setup.flat_rank_constraints,
    )
  let root_mincross_reorder_inputs : RootMincrossReorderInputs =
    {
      order_with_clusters: reorder_setup.order_with_clusters,
      order_with_vnodes: reorder_setup.order_with_vnodes,
      seeded_groups,
      order_rank_keys: reorder_context.order_rank_keys,
      order_ranks: reorder_context.order_ranks,
      order_edges_out: materialized.order_edges_out,
      order_edge_tail_out: materialized.order_edge_tail_out,
      order_edge_head_out: materialized.order_edge_head_out,
      order_edge_tail_port_x: materialized.order_edge_tail_port_x,
      order_edge_head_port_x: materialized.order_edge_head_port_x,
      order_edge_tail_port_order: materialized.order_edge_tail_port_order,
      order_edge_head_port_order: materialized.order_edge_head_port_order,
      order_cluster_keys: pre_root_stage.order_cluster_keys,
      order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
      rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
      rank_same_order: dispatch_context.cluster_meta.rank_same_order,
      vnode_order_keys_for_ordering: reorder_setup.vnode_order_keys_for_ordering,
      order_node_order: reorder_context.order_node_order,
      order_sizes_out: pre_root_stage.order_sizes_out,
      nodesep_pt: dispatch_context.nodesep_pt,
      has_edge_labels: dispatch_context.has_edge_labels,
      port_order_positions: dispatch_context.port_order_positions,
      port_order_contrib: dispatch_context.port_order_contrib,
      order_flat_constraints: materialized.order_flat_constraints,
      graphviz_out_neighbors: materialized.graphviz_out_neighbors,
      graphviz_in_neighbors: materialized.graphviz_in_neighbors,
      graphviz_flip: reorder_setup.graphviz_flip,
    }
  let (order_groups_for_mincross, root_ordered_groups) =
    run_root_mincross_reorder(root_mincross_reorder_inputs)
  let ordered =
    if !reorder_setup.graphviz_flip {
      root_ordered_groups
    } else {
      match root_mincross_groups_override.val {
        Some(override_groups) =>
          apply_root_groups_override(
            root_ordered_groups,
            override_groups,
            dispatch_context.cluster_meta.cluster_keys,
            reorder_setup.graphviz_flip,
          )
        None => root_ordered_groups
      }
    }
  // Graphviz parity: clustered order pass runs cluster-local build_ranks on
  // the unmapped order graph, then stores vnode-inclusive rank groups for xpos.
  if reorder_setup.order_with_clusters {
    reorder_by_cluster_ranks(
      dispatch_context.graph,
      ordered,
      dispatch_context.cluster_meta,
      reorder_context.order_node_order,
      materialized.order_edges_out_unmapped,
      materialized.order_edge_tail_out_unmapped,
      materialized.order_edge_head_out_unmapped,
      materialized.order_edge_tail_port_x_unmapped,
      materialized.order_edge_head_port_x_unmapped,
      materialized.order_edge_tail_port_order_unmapped,
      materialized.order_edge_head_port_order_unmapped,
      materialized.graphviz_out_neighbors,
      materialized.graphviz_in_neighbors,
      dispatch_context.ranks,
      pre_root_stage.order_sizes_out,
      dispatch_context.nodesep_pt,
      dispatch_context.has_edge_labels,
      dispatch_context.port_order_positions,
      dispatch_context.port_order_contrib,
      runtime_context.vnode_info,
      reorder_setup.order_with_vnodes,
    )
  }
  let next_ordered_with_vnodes =
    if !reorder_setup.order_with_vnodes {
      Map::new()
    } else {
      ordered
    }
  {
    order_groups_for_mincross,
    ordered,
    ordered_with_vnodes: next_ordered_with_vnodes,
  }
}
