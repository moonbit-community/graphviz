///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// stage-dispatch type definitions for phase orchestration.

///|
/// Graphviz parity: clustered pre-root stage output carries grouped sizes,
/// cluster skeleton maps, reorder context, and materialized edges unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredPreRootData {
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  reorder_context : OrderReorderContext
  materialized : OrderMaterializationData
}

///|
/// Graphviz parity: clustered ordering stage dispatch context keeps complete
/// clustered ordering payload ordering unchanged before stage execution.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredDispatchContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  edge_port_data : OrderingEdgePortData
  reorder_setup : OrderingReorderSetup
  class2_data : OrderingClass2Data
}

///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// pre-root/root/finalize stage orchestration helpers.

///|
/// Graphviz parity: clustered pre-root ordering preparation keeps order-group
/// expansion, reorder context, and materialization sequence aligned to Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root(
  dispatch_context : ClusteredDispatchContext,
) -> ClusteredPreRootData {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let order_seed_output =
    build_order_seed_groups(
      reorder_setup.ordering_groups_base,
      reorder_setup.base_order_index,
      reorder_setup.order_with_vnodes,
      reorder_setup.order_with_clusters,
      dispatch_context.cluster_meta,
      runtime_context.vnode_info,
      reorder_setup.vnode_order_keys_for_ordering,
      dispatch_context.order_sizes,
    )
  let order_groups = order_seed_output.order_groups
  let order_sizes_out = order_seed_output.order_sizes_out
  let order_cluster_keys = order_seed_output.order_cluster_keys
  let order_cluster_skeleton = order_seed_output.order_cluster_skeleton
  let reorder_context =
    build_order_reorder_context(
      order_groups,
      class2_data.nlist_order,
      reorder_setup.gdnlist_order,
      dispatch_context.node_order,
      runtime_context.real_nodes,
      dispatch_context.cluster_meta.has_clusters,
      reorder_setup.base_order_index,
      dispatch_context.cluster_meta.rank_same_groups,
      dispatch_context.cluster_meta.rank_same_order,
      runtime_context.port_edge_nodes,
    )
  let materialized =
    build_materialized_inputs(
      class2_data.nlist_order,
      class2_data.order_edges_by_tail,
      reorder_context.order_graph,
      reorder_context.order_node_map,
      class2_data.order_edges_by_tail_unmapped,
      reorder_context.order_graph_unmapped,
      reorder_context.order_node_map_unmapped,
      runtime_context.real_nodes,
      reorder_context.order_nodes,
      class2_data.edge_creation_order,
      dispatch_context.cluster_meta,
      reorder_setup.gdnlist_order,
      dispatch_context.edge_tail,
      dispatch_context.edge_head,
      dispatch_context.nodes,
      reorder_context.order_node_order,
    )
  {
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
    reorder_context,
    materialized,
  }
}

///|
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_root_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> OrderRootClusterData {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let reorder_context = pre_root_stage.reorder_context
  let materialized = pre_root_stage.materialized
  remincross_root_tail_order_override_snapshot.val = None
  let root_reorder_sources : RootReorderBuildSources =
    {
      order_with_vnodes: reorder_setup.order_with_vnodes,
      order_rank_keys: reorder_context.order_rank_keys,
      order_groups_for_mincross: pre_root_stage.order_groups,
      order_cluster_keys: pre_root_stage.order_cluster_keys,
      order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
      edges: dispatch_context.edges,
      edge_tail: dispatch_context.edge_tail,
      edge_head: dispatch_context.edge_head,
      cluster_keys: dispatch_context.cluster_meta.cluster_keys,
      edge_vnodes: runtime_context.vnode_info.edge_vnodes,
      vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
      vnode_order_keys_for_ordering: reorder_setup.vnode_order_keys_for_ordering,
      nlist_order: class2_data.nlist_order,
      ranks: dispatch_context.ranks,
      skeleton_edge_creation: class2_data.skeleton_edge_creation,
      root_edge_creation: class2_data.root_edge_creation,
      flat_rank_constraints: reorder_setup.flat_rank_constraints,
    }
  let root_reorder_output : RootClusterReorderInputs =
    build_root_reorder_inputs(
      root_reorder_sources,
      class2_data.order_edges_by_tail_root,
    )
  // Graphviz parity: root-phase tail override keeps first-seen tail replay
  // order while suppressing duplicate tail names from root-edge replay
  // sequences.
  let root_tail_order_override : Array[String] = []
  let seen_root_tail : Map[String, Bool] = Map::new()
  for tail in root_reorder_output.root_edge_tail_out {
    append_creation_name(root_tail_order_override, seen_root_tail, tail)
  }
  let root_phase_inputs : RootRankOrderPhaseInputs =
    {
      order_cluster_keys: pre_root_stage.order_cluster_keys,
      rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
      rank_same_order: dispatch_context.cluster_meta.rank_same_order,
      order_sizes_out: pre_root_stage.order_sizes_out,
      nodesep_pt: dispatch_context.nodesep_pt,
      has_edge_labels: dispatch_context.has_edge_labels,
      port_order_positions: dispatch_context.port_order_positions,
      port_order_contrib: dispatch_context.port_order_contrib,
      order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
      flat_constraints: dispatch_context.cluster_meta.flat_constraints,
      graphviz_flip: reorder_setup.graphviz_flip,
      root_reorder_output,
    }
  let root_rank_order_phase_output =
    run_root_rank_order_phase(root_phase_inputs)
  let root_groups_override = root_rank_order_phase_output.ordered_root
  // Graphviz parity: clustered root phase sets both tail-order and group
  // overrides only in cluster mode; otherwise both override channels are
  // cleared.
  if reorder_setup.order_with_clusters {
    remincross_root_tail_order_override_snapshot.val =
      Some(root_tail_order_override.copy())
    root_mincross_groups_override.val =
      Some(clone_rank_groups(root_groups_override))
  } else {
    remincross_root_tail_order_override_snapshot.val = None
    root_mincross_groups_override.val = None
  }
  let build_ranks_inputs : RootClusterBuildRanksInputs =
    {
      order_node_order: reorder_context.order_node_order,
      order_sizes_out: pre_root_stage.order_sizes_out,
      order_rank_keys: reorder_context.order_rank_keys,
      order_groups: pre_root_stage.order_groups,
      order_ranks: reorder_context.order_ranks,
      order_cluster_keys: pre_root_stage.order_cluster_keys,
      order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
      order_flat_constraints: materialized.order_flat_constraints,
      graphviz_out_neighbors: materialized.graphviz_out_neighbors,
      graphviz_in_neighbors: materialized.graphviz_in_neighbors,
      order_edges_out: materialized.order_edges_out,
      order_edge_tail_out: materialized.order_edge_tail_out,
      order_edge_head_out: materialized.order_edge_head_out,
      order_edge_tail_port_x: materialized.order_edge_tail_port_x,
      order_edge_head_port_x: materialized.order_edge_head_port_x,
      order_edge_tail_port_order: materialized.order_edge_tail_port_order,
      order_edge_head_port_order: materialized.order_edge_head_port_order,
      order_edges_out_unmapped: materialized.order_edges_out_unmapped,
      order_edge_tail_out_unmapped: materialized.order_edge_tail_out_unmapped,
      order_edge_head_out_unmapped: materialized.order_edge_head_out_unmapped,
      order_edge_tail_port_x_unmapped: materialized.order_edge_tail_port_x_unmapped,
      order_edge_head_port_x_unmapped: materialized.order_edge_head_port_x_unmapped,
      order_edge_tail_port_order_unmapped:
        materialized.order_edge_tail_port_order_unmapped,
      order_edge_head_port_order_unmapped:
        materialized.order_edge_head_port_order_unmapped,
      ordered_with_vnodes: Map::new(),
    }
  let output =
    run_root_and_cluster_ranks(
      {
        order_with_clusters: reorder_setup.order_with_clusters,
        order_with_vnodes: reorder_setup.order_with_vnodes,
        graph: dispatch_context.graph,
        cluster_meta: dispatch_context.cluster_meta,
        vnode_order_keys_for_ordering:
          reorder_setup.vnode_order_keys_for_ordering,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        graphviz_flip: reorder_setup.graphviz_flip,
        flat_rank_constraints: reorder_setup.flat_rank_constraints,
        ranks: dispatch_context.ranks,
        vnode_info: runtime_context.vnode_info,
        build_ranks_inputs,
      },
    )
  root_mincross_groups_override.val = None
  output
}

///|
/// Graphviz parity: clustered finalize phase first applies root cluster-rank
/// ordering, then runs final clustered ReMincross with unchanged call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_finalize_phase(
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_cluster_stage : OrderRootClusterData,
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let class2_data = dispatch_context.class2_data
  let runtime_context = dispatch_context.runtime_context
  let reorder_context = pre_root_stage.reorder_context
  let cluster_rank_order_inputs : ClusterRankOrderBuildInputs =
    {
      order_with_clusters: reorder_setup.order_with_clusters,
      order_with_vnodes: reorder_setup.order_with_vnodes,
      graphviz_flip: reorder_setup.graphviz_flip,
      edges: dispatch_context.edges,
      edge_tail: dispatch_context.edge_tail,
      edge_head: dispatch_context.edge_head,
      nlist_order: class2_data.nlist_order,
      ranks: dispatch_context.ranks,
      order_rank_keys: reorder_context.order_rank_keys,
      order_groups_for_mincross: root_cluster_stage.order_groups_for_mincross,
      order_cluster_keys: pre_root_stage.order_cluster_keys,
      order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
      order_edges_by_tail_root: class2_data.order_edges_by_tail_root,
      skeleton_edge_creation: class2_data.skeleton_edge_creation,
      root_edge_creation: class2_data.root_edge_creation,
      flat_rank_constraints: reorder_setup.flat_rank_constraints,
      cluster_meta: dispatch_context.cluster_meta,
      vnode_info: runtime_context.vnode_info,
      vnode_order_keys_for_ordering:
        reorder_setup.vnode_order_keys_for_ordering,
      real_nodes: runtime_context.real_nodes,
      order_sizes_out: pre_root_stage.order_sizes_out,
      nodesep_pt: dispatch_context.nodesep_pt,
      has_edge_labels: dispatch_context.has_edge_labels,
      port_order_positions: dispatch_context.port_order_positions,
      port_order_contrib: dispatch_context.port_order_contrib,
    }
  let cluster_rank_order =
    build_cluster_rank_order(
      cluster_rank_order_inputs,
    )
  let finalize_order_inputs : FinalizeOrderGroupsInputs =
    {
      order_with_clusters: reorder_setup.order_with_clusters,
      order_with_vnodes: reorder_setup.order_with_vnodes,
      cluster_rank_order,
      cluster_meta: dispatch_context.cluster_meta,
      local_cluster_order: runtime_context.local_cluster_order,
      ordered_with_vnodes: root_cluster_stage.ordered_with_vnodes,
      graph: dispatch_context.graph,
      edges: dispatch_context.edges,
      edge_tail: dispatch_context.edge_tail,
      edge_head: dispatch_context.edge_head,
      edge_reversed: dispatch_context.edge_reversed,
      edge_tail_port_x: dispatch_context.edge_port_data.edge_tail_port_x,
      edge_head_port_x: dispatch_context.edge_port_data.edge_head_port_x,
      edge_tail_port_order: dispatch_context.edge_port_data.edge_tail_port_order,
      edge_head_port_order: dispatch_context.edge_port_data.edge_head_port_order,
      ranks: dispatch_context.ranks,
      creation_order: reorder_context.creation_order,
      edges_by_tail: class2_data.edges_by_tail,
      vnode_info: runtime_context.vnode_info,
      order_sizes: dispatch_context.order_sizes,
      rank_same_constraints: runtime_context.rank_same_constraints,
      real_nodes: runtime_context.real_nodes,
      graphviz_flip: reorder_setup.graphviz_flip,
      nodesep_pt: dispatch_context.nodesep_pt,
      has_edge_labels: dispatch_context.has_edge_labels,
      port_order_positions: dispatch_context.port_order_positions,
      port_order_contrib: dispatch_context.port_order_contrib,
      order_rank_keys: reorder_context.order_rank_keys,
      ordered: root_cluster_stage.ordered,
    }
  let finalize_output =
    finalize_order_groups(
      finalize_order_inputs,
    )
  {
    ordered_groups: finalize_output.ordered_groups,
    ordered_with_vnodes: finalize_output.ordered_with_vnodes,
  }
}

///|
/// Graphviz parity: clustered ordering path keeps build_ranks/mincross phase
/// boundaries unchanged while delegating each phase to base helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered(
  dispatch_context : ClusteredDispatchContext,
) -> OrderingDispatchOutput {
  let pre_root_stage = build_clustered_pre_root(dispatch_context)
  let root_cluster_stage =
    run_clustered_root_phase(
      dispatch_context,
      pre_root_stage,
    )
  let output =
    run_clustered_finalize_phase(
      dispatch_context,
      pre_root_stage,
      root_cluster_stage,
    )
  remincross_root_tail_order_override_snapshot.val = None
  output
}
