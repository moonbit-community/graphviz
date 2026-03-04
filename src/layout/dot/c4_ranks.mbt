///|
/// Stage C Phase C4 split: root+cluster build_ranks
/// and reorder helpers for root-cluster arrangement.

///|
/// Graphviz parity: build_ranks seeding runs component-scoped ordering first,
/// then applies transpose when crossings remain (port-offset aware tie-breaks).
/// Do not change behavior without updating fixtures/tests.
fn build_seeded_reorder_groups(
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
  // Graphviz parity: seed build_ranks from component-scoped walk,
  // matching decompose/install traversal used by remincross with
  // cluster-expanded flat constraints.
  let seed_pass =
    if @sys.get_env_var("DOT_SEED_PASS1") is Some(_) { 1 } else { 0 }
  let seeded_groups = build_component_rank_groups(
    order_rank_keys,
    order_groups,
    order_edge_tail_out,
    order_edge_head_out,
    order_ranks,
    order_node_order,
    order_cluster_keys,
    order_cluster_skeleton,
    seed_pass,
    order_flat_constraints,
    flip=graphviz_flip,
    graphviz_out_neighbors=graphviz_out_neighbors,
    graphviz_in_neighbors=graphviz_in_neighbors,
  )
  // Graphviz parity: build_ranks applies transpose if crossings remain;
  // crossing count uses endpoint port x offsets for tie-correct ordering.
  let seed_cross = @ordering.count_crossings_port_aware(
    seeded_groups,
    order_ranks,
    order_edges_out,
    order_edge_tail_out,
    order_edge_head_out,
    edge_tail_port_x=order_edge_tail_port_x,
    edge_head_port_x=order_edge_head_port_x,
  )
  if seed_cross > 0 {
    let transpose_seed_maps =
      @ordering.build_transpose_seed_maps(
        order_rank_keys,
        seeded_groups,
        order_edges_out,
        order_edge_tail_out,
        order_edge_head_out,
        order_ranks,
      )
    let _ = transpose_rank_groups_port(
      order_rank_keys,
      seeded_groups,
      order_ranks,
      transpose_seed_maps.edge_in,
      transpose_seed_maps.edge_out,
      order_edge_tail_out,
      order_edge_head_out,
      order_edge_tail_port_x,
      order_edge_head_port_x,
      transpose_seed_maps.edge_penalty,
      order_cluster_keys,
      order_cluster_skeleton,
      flat_rank_constraints,
      false,
      0,
    )
  }
  seeded_groups
}

///|
/// Graphviz parity: root ReMincross rank reorder call uses the same
/// reorder_rank_groups wiring as Graphviz root mincross pass.
fn run_root_mincross_reorder_call(
  reorder_inputs : @ordering.RootRankReorderInputs,
  root_graphviz_flip : Bool,
  coalesce_parallel : Bool,
) -> Map[Int, Array[String]] {
  reorder_rank_groups(
    reorder_inputs.order_rank_keys_for_mincross,
    reorder_inputs.order_groups_for_mincross,
    reorder_inputs.order_edges_out_mincross,
    reorder_inputs.order_edge_tail_out_mincross,
    reorder_inputs.order_edge_head_out_mincross,
    reorder_inputs.order_edge_tail_port_x_mincross,
    reorder_inputs.order_edge_head_port_x_mincross,
    reorder_inputs.order_edge_tail_port_order_mincross,
    reorder_inputs.order_edge_head_port_order_mincross,
    reorder_inputs.parents,
    reorder_inputs.children,
    reorder_inputs.order_cluster_keys,
    reorder_inputs.rank_same_groups,
    reorder_inputs.rank_same_order,
    reorder_inputs.edge_order,
    reorder_inputs.order_node_order,
    reorder_inputs.order_sizes_out,
    reorder_inputs.nodesep_pt,
    reorder_inputs.has_edge_labels,
    reorder_inputs.port_order_positions,
    reorder_inputs.port_order_contrib,
    reorder_inputs.preferred_positions,
    reorder_inputs.order_cluster_skeleton,
    reorder_inputs.order_flat_constraints,
    graphviz_out_neighbors=reorder_inputs.graphviz_out_neighbors,
    graphviz_in_neighbors=reorder_inputs.graphviz_in_neighbors,
    graphviz_flip=root_graphviz_flip,
    coalesce_parallel_edges=coalesce_parallel,
  )
}

///|
/// Graphviz parity: root ReMincross pass reorders only root/skeleton members,
/// then merges reordered root positions back into seeded build_ranks groups.
/// Do not change behavior without updating fixtures/tests.
fn run_root_mincross_reorder(
  inputs : @ordering.RootMincrossReorderInputs,
  order_groups_override : Map[Int, Array[String]]?,
) -> @ordering.RootMincrossReorderResult {
  // Graphviz parity: pass0 flat-seed capture wraps the root rank-reorder call,
  // then records the same stage snapshot before resetting capture state.
  capture_pass0_flat_seed_groups_value.val = None
  capture_pass0_flat_seed_groups_enabled.val = true
  let result =
    @ordering.run_root_mincross_reorder(
      inputs,
      order_groups_override,
      run_root_mincross_reorder_call,
    )
  capture_pass0_flat_seed_groups_enabled.val = false
  capture_root_mincross_pass_snapshot(result, inputs)
  capture_pass0_flat_seed_groups_value.val = None
  result
}

///|
/// Graphviz parity: root-mincross reorder payload is assembled from clustered
/// pre-root snapshots after seeded build_ranks groups are produced.
/// Do not change behavior without updating fixtures/tests.
fn build_root_mincross_reorder_inputs(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  seeded_groups : Map[Int, Array[String]],
) -> @ordering.RootMincrossReorderInputs {
  let reorder_setup = dispatch_context.reorder_setup
  let reorder_context = pre_root_stage.reorder_context
  let materialized = pre_root_stage.materialized
  let root_reorder_context : @ordering.RootMincrossReorderBuildContext =
    {
      order_with_clusters: reorder_setup.order_with_clusters,
      order_with_vnodes: reorder_setup.order_with_vnodes,
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
  @ordering.build_root_mincross_reorder_inputs(
    seeded_groups,
    root_reorder_context,
  )
}

///|
/// Graphviz parity: root mincross output is replayed into clustered build_ranks
/// using unmapped order-edge arrays before final clustered cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_rank_reorder(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  ordered : Map[Int, Array[String]],
) -> Unit {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  let reorder_context = pre_root_stage.reorder_context
  let materialized = pre_root_stage.materialized
  reorder_by_cluster_ranks(
    ordered,
    {
      graph: dispatch_context.graph,
      cluster_meta: dispatch_context.cluster_meta,
      node_order: reorder_context.order_node_order,
      order_edges: materialized.order_edges_out_unmapped,
      order_edge_tail: materialized.order_edge_tail_out_unmapped,
      order_edge_head: materialized.order_edge_head_out_unmapped,
      order_edge_tail_port_x: materialized.order_edge_tail_port_x_unmapped,
      order_edge_head_port_x: materialized.order_edge_head_port_x_unmapped,
      order_edge_tail_port_order: materialized.order_edge_tail_port_order_unmapped,
      order_edge_head_port_order: materialized.order_edge_head_port_order_unmapped,
      graphviz_out_neighbors: materialized.graphviz_out_neighbors,
      graphviz_in_neighbors: materialized.graphviz_in_neighbors,
      ranks: dispatch_context.ranks,
      order_sizes: pre_root_stage.order_sizes_out,
      nodesep_pt: dispatch_context.nodesep_pt,
      has_edge_labels: dispatch_context.has_edge_labels,
      port_order_positions: dispatch_context.port_order_positions,
      port_order_contrib: dispatch_context.port_order_contrib,
      vnode_info: runtime_context.vnode_info,
      order_with_vnodes: reorder_setup.order_with_vnodes,
    },
  )
}

///|
/// Graphviz parity: clustered root phase seeds build_ranks using mapped order
/// edges plus Graphviz ND_out/ND_in neighbors before root-mincross reorder.
/// Do not change behavior without updating fixtures/tests.
fn build_seeded_groups_for_root_and_cluster(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> Map[Int, Array[String]] {
  let reorder_setup = dispatch_context.reorder_setup
  let reorder_context = pre_root_stage.reorder_context
  let materialized = pre_root_stage.materialized
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
}

///|
/// Graphviz parity: root+cluster rank phase input keeps root override and
/// root-mincross payload unchanged before ordering package orchestration.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_ranks_inputs(
  dispatch_context : ClusteredDispatchContext,
  root_groups_override : Map[Int, Array[String]]?,
  root_mincross_reorder_inputs : @ordering.RootMincrossReorderInputs,
) -> @ordering.RootAndClusterRanksInputs {
  let reorder_setup = dispatch_context.reorder_setup
  {
    order_with_clusters: reorder_setup.order_with_clusters,
    order_with_vnodes: reorder_setup.order_with_vnodes,
    graphviz_flip: reorder_setup.graphviz_flip,
    cluster_keys: dispatch_context.cluster_meta.cluster_keys,
    root_groups_override,
    root_mincross_reorder_inputs,
  }
}

///|
/// Graphviz parity: root mincross reordering is followed by clustered
/// build_ranks application on the unmapped order graph before final cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_ranks(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_groups_override : Map[Int, Array[String]]?,
) -> @ordering.RootAndClusterRanksOutput {
  let seeded_groups =
    build_seeded_groups_for_root_and_cluster(
      dispatch_context,
      pre_root_stage,
    )
  let root_mincross_reorder_inputs =
    build_root_mincross_reorder_inputs(
      dispatch_context,
      pre_root_stage,
      seeded_groups,
    )
  let output =
    @ordering.run_root_and_cluster_ranks(
      build_root_and_cluster_ranks_inputs(
        dispatch_context,
        root_groups_override,
        root_mincross_reorder_inputs,
      ),
      run_root_mincross_reorder,
      (ordered) =>
        run_clustered_rank_reorder(
          dispatch_context,
          pre_root_stage,
          ordered,
        ),
    )
  output
}
