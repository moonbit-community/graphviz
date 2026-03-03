///|
/// Stage C Phase C2 split: root mincross/replay helpers
/// for primary crossing-reduction ordering passes.

///|
/// Graphviz parity: root mincross reorder dispatch funnels both single- and
/// component-path payloads through one reorder_rank_groups call shape.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_reorder_call(
  inputs : @ordering.RootRankReorderInputs,
  root_graphviz_flip : Bool,
  coalesce_parallel : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    inputs.order_rank_keys_for_mincross,
    inputs.order_groups_for_mincross,
    inputs.order_edges_out_mincross,
    inputs.order_edge_tail_out_mincross,
    inputs.order_edge_head_out_mincross,
    inputs.order_edge_tail_port_x_mincross,
    inputs.order_edge_head_port_x_mincross,
    inputs.order_edge_tail_port_order_mincross,
    inputs.order_edge_head_port_order_mincross,
    inputs.parents,
    inputs.children,
    inputs.order_cluster_keys,
    inputs.rank_same_groups,
    inputs.rank_same_order,
    inputs.edge_order,
    inputs.order_node_order,
    inputs.order_sizes_out,
    inputs.nodesep_pt,
    inputs.has_edge_labels,
    inputs.port_order_positions,
    inputs.port_order_contrib,
    inputs.preferred_positions,
    inputs.order_cluster_skeleton,
    inputs.order_flat_constraints,
    graphviz_out_neighbors=inputs.graphviz_out_neighbors,
    graphviz_in_neighbors=inputs.graphviz_in_neighbors,
    graphviz_flip=root_graphviz_flip,
    coalesce_parallel_edges=coalesce_parallel,
  )
}

///|
/// Graphviz parity: root ReMincross runs mincross per connected component
/// (dot_mincross init_mccomp loop), then concatenates rank output by component.
/// Do not change behavior without updating fixtures/tests.
fn run_root_rank_reorder(
  inputs : @ordering.RootRankReorderInputs,
) -> Map[Int, Array[String]] {
  let (components, root_graphviz_flip) =
    @ordering.build_root_component_runtime_plan(
      inputs.order_cluster_keys,
      inputs.graphviz_flip,
      inputs.order_rank_keys_for_mincross,
      inputs.order_groups_for_mincross,
      inputs.order_node_order,
      inputs.graphviz_out_neighbors,
      inputs.graphviz_in_neighbors,
      inputs.order_flat_constraints,
    )
  let coalesce_parallel =
    @sys.get_env_var("DOT_NO_COALESCE_PARALLEL") is None
  if components.length() <= 1 {
    return run_root_rank_reorder_call(
      inputs,
      root_graphviz_flip,
      coalesce_parallel,
    )
  }
  @ordering.run_componentwise_root_rank_reorder(
    components,
    inputs.order_rank_keys_for_mincross,
    (component_nodes, component_set) => {
      let reorder_call_inputs =
        @ordering.build_root_component_reorder_inputs(
          component_nodes,
          component_set,
          inputs,
        )
      run_root_rank_reorder_call(
        reorder_call_inputs,
        root_graphviz_flip,
        coalesce_parallel,
      )
    },
  )
}

///|
/// Graphviz parity: root ReMincross input bundle keeps seeded groups, edge
/// snapshots, cluster metadata, and rank-order settings unchanged for replay.
/// Do not change behavior without updating fixtures/tests.
priv struct RootMincrossReorderInputs {
  order_with_clusters : Bool
  order_with_vnodes : Bool
  seeded_groups : Map[Int, Array[String]]
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_edges_out : Array[@cgraph.Edge]
  order_edge_tail_out : Array[String]
  order_edge_head_out : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  cluster_meta : ClusterMetadata
  vnode_order_keys_for_ordering : Map[String, Double]
  order_node_order : Map[String, Int]
  order_sizes_out : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  order_flat_constraints : Map[String, Bool]
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  graphviz_flip : Bool
}

///|
/// Graphviz parity: root ReMincross rank-reorder pass keeps input preparation
/// and reorder_rank_groups execution in the same Graphviz call sequence.
/// Do not change behavior without updating fixtures/tests.
fn run_root_reorder_pass(
  reorder_inputs : RootMincrossReorderInputs,
  order_groups_for_mincross : Map[Int, Array[String]],
) -> (Map[Int, Array[String]], Map[String, Bool]) {
  // Graphviz parity: root ReMincross stage data is assembled from one
  // snapshot: rank keys -> node membership -> filtered mincross edge bundle.
  let order_rank_keys_for_mincross =
    @ordering.collect_rank_keys(order_groups_for_mincross)
  let order_nodes_for_mincross =
    @ordering.build_order_nodes_from_groups(
      order_groups_for_mincross,
      order_rank_keys_for_mincross,
    )
  let mincross_nodes =
    @ordering.build_node_membership_set(order_nodes_for_mincross)
  let mincross_edge_data =
    @ordering.build_root_mincross_edge_bundle(
      mincross_nodes,
      order_nodes_for_mincross,
      reorder_inputs.order_edges_out,
      reorder_inputs.order_edge_tail_out,
      reorder_inputs.order_edge_head_out,
      reorder_inputs.order_edge_tail_port_x,
      reorder_inputs.order_edge_head_port_x,
      reorder_inputs.order_edge_tail_port_order,
      reorder_inputs.order_edge_head_port_order,
      reorder_inputs.order_ranks,
    )
  let preferred_positions =
    @ordering.build_root_vnode_preferred_positions(
      reorder_inputs.order_with_vnodes,
      reorder_inputs.vnode_order_keys_for_ordering,
    )
  // Graphviz parity: root ReMincross rank-reorder input preserves the stage
  // edge snapshot and root-order metadata when dispatching reorder_rank_groups.
  let root_rank_reorder_inputs : @ordering.RootRankReorderInputs =
    {
      order_rank_keys_for_mincross,
      order_groups_for_mincross,
      order_edges_out_mincross: mincross_edge_data.order_edges_out_mincross,
      order_edge_tail_out_mincross:
        mincross_edge_data.order_edge_tail_out_mincross,
      order_edge_head_out_mincross:
        mincross_edge_data.order_edge_head_out_mincross,
      order_edge_tail_port_x_mincross:
        mincross_edge_data.order_edge_tail_port_x_mincross,
      order_edge_head_port_x_mincross:
        mincross_edge_data.order_edge_head_port_x_mincross,
      order_edge_tail_port_order_mincross:
        mincross_edge_data.order_edge_tail_port_order_mincross,
      order_edge_head_port_order_mincross:
        mincross_edge_data.order_edge_head_port_order_mincross,
      parents: mincross_edge_data.parents,
      children: mincross_edge_data.children,
      order_cluster_keys: reorder_inputs.order_cluster_keys,
      rank_same_groups: reorder_inputs.cluster_meta.rank_same_groups,
      rank_same_order: reorder_inputs.cluster_meta.rank_same_order,
      edge_order: mincross_edge_data.edge_order,
      order_node_order: reorder_inputs.order_node_order,
      order_sizes_out: reorder_inputs.order_sizes_out,
      nodesep_pt: reorder_inputs.nodesep_pt,
      has_edge_labels: reorder_inputs.has_edge_labels,
      port_order_positions: reorder_inputs.port_order_positions,
      port_order_contrib: reorder_inputs.port_order_contrib,
      preferred_positions,
      order_cluster_skeleton: reorder_inputs.order_cluster_skeleton,
      order_flat_constraints: reorder_inputs.order_flat_constraints,
      graphviz_out_neighbors: reorder_inputs.graphviz_out_neighbors,
      graphviz_in_neighbors: reorder_inputs.graphviz_in_neighbors,
      graphviz_flip: reorder_inputs.graphviz_flip,
    }
  // Graphviz parity: pass0 flat-seed capture wraps the root rank-reorder call,
  // then records the same stage snapshot before resetting capture state.
  capture_pass0_flat_seed_groups_value.val = None
  capture_pass0_flat_seed_groups_enabled.val = true
  let ordered_mincross =
    run_root_rank_reorder(root_rank_reorder_inputs)
  capture_pass0_flat_seed_groups_enabled.val = false
  // Graphviz parity: root reorder pass snapshot records the same mincross
  // edge projection and selected rank groups passed to reorder_rank_groups.
  capture_root_snapshot(
    order_rank_keys_for_mincross,
    order_groups_for_mincross,
    mincross_edge_data.order_edges_out_mincross,
    mincross_edge_data.order_edge_tail_out_mincross,
    mincross_edge_data.order_edge_head_out_mincross,
    mincross_edge_data.order_edge_tail_port_x_mincross,
    mincross_edge_data.order_edge_head_port_x_mincross,
    mincross_edge_data.order_edge_tail_port_order_mincross,
    mincross_edge_data.order_edge_head_port_order_mincross,
    reorder_inputs.order_cluster_keys,
    reorder_inputs.order_cluster_skeleton,
  )
  capture_pass0_flat_seed_groups_value.val = None
  (ordered_mincross, mincross_nodes)
}

///|
/// Graphviz parity: root ReMincross input groups are cluster-filtered when
/// cluster ordering is enabled, then optionally overridden for fixture replay.
/// Do not change behavior without updating fixtures/tests.
fn resolve_root_mincross_input_groups(
  inputs : RootMincrossReorderInputs,
) -> Map[Int, Array[String]] {
  let order_groups_for_mincross_base =
    if !inputs.order_with_clusters {
      inputs.seeded_groups
    } else {
      // Graphviz parity: root ReMincross keeps only root and cluster-skeleton
      // nodes; cluster-internal ordering stays in cluster-local build_ranks
      // passes.
      @ordering.filter_root_mincross_seeded_groups_for_clusters(
        inputs.seeded_groups,
        inputs.order_cluster_keys,
        inputs.order_cluster_skeleton,
      )
    }
  match root_mincross_groups_override.val {
    Some(override_groups) => @ordering.clone_rank_groups(override_groups)
    None => order_groups_for_mincross_base
  }
}

///|
/// Graphviz parity: root ReMincross output merges reordered root/skeleton names
/// back to seeded groups only in cluster-order mode.
/// Do not change behavior without updating fixtures/tests.
fn finalize_root_mincross_ordered_groups(
  inputs : RootMincrossReorderInputs,
  ordered_mincross : Map[Int, Array[String]],
  mincross_nodes : Map[String, Bool],
) -> Map[Int, Array[String]] {
  if !inputs.order_with_clusters {
    return ordered_mincross
  }
  @ordering.merge_root_mincross_groups(
    inputs.order_rank_keys,
    inputs.seeded_groups,
    ordered_mincross,
    mincross_nodes,
    inputs.order_cluster_keys,
    inputs.order_cluster_skeleton,
  )
}

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder(
  inputs : RootMincrossReorderInputs,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let order_groups_for_mincross =
    resolve_root_mincross_input_groups(inputs)
  let (ordered_mincross, mincross_nodes) =
    run_root_reorder_pass(inputs, order_groups_for_mincross)
  let ordered =
    finalize_root_mincross_ordered_groups(
      inputs,
      ordered_mincross,
      mincross_nodes,
    )
  (order_groups_for_mincross, ordered)
}
