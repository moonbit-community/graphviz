///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// stage-dispatch type definitions for phase orchestration.

///|
/// Graphviz parity: clustered pre-root stage context keeps order-group,
/// reorder/materialize, and vnode payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredOrderingPreRootStageContext {
  ordering_groups_base : Map[Int, Array[String]]
  base_order_index : Map[String, Int]
  order_with_vnodes : Bool
  order_with_clusters : Bool
  cluster_meta : ClusterMetadata
  vnode_info : EdgeVnodeInfo
  vnode_order_keys_for_ordering : Map[String, Double]
  order_sizes : Map[String, NodeSize]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  node_order : Map[String, Int]
  real_nodes : Map[String, Bool]
  port_edge_nodes : Map[String, Bool]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  edge_creation_order : Array[(String, String)]
  edge_tail : Array[String]
  edge_head : Array[String]
  nodes : Array[@cgraph.Node]
}

///|
/// Graphviz parity: clustered pre-root stage output carries grouped sizes,
/// cluster skeleton maps, reorder context, and materialized edges unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderClusteredPreRootStageData {
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
priv struct ClusteredOrderingStageDispatchContext {
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
fn build_clustered_ordering_pre_root_stage(
  context : ClusteredOrderingPreRootStageContext,
) -> OrderClusteredPreRootStageData {
  let (
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
  ) =
    build_order_groups_sizes_and_cluster_skeleton(
      context.ordering_groups_base,
      context.base_order_index,
      context.order_with_vnodes,
      context.order_with_clusters,
      context.cluster_meta,
      context.vnode_info,
      context.vnode_order_keys_for_ordering,
      context.order_sizes,
    )
  dot_trace_groups("order_groups_pre", order_groups)
  let reorder_context =
    build_order_reorder_context(
      order_groups,
      context.nlist_order,
      context.gdnlist_order,
      context.node_order,
      context.real_nodes,
      context.cluster_meta.has_clusters,
      context.base_order_index,
      context.cluster_meta.rank_same_groups,
      context.cluster_meta.rank_same_order,
      context.port_edge_nodes,
    )
  trace_order_node_order_debug(reorder_context.order_node_order)
  let materialized_inputs : MaterializedOrderEdgesAndNeighborsContext = {
    nlist_order: context.nlist_order,
    order_edges_by_tail: context.order_edges_by_tail,
    order_graph: reorder_context.order_graph,
    order_node_map: reorder_context.order_node_map,
    order_edges_by_tail_unmapped: context.order_edges_by_tail_unmapped,
    order_graph_unmapped: reorder_context.order_graph_unmapped,
    order_node_map_unmapped: reorder_context.order_node_map_unmapped,
    order_ranks: reorder_context.order_ranks,
    real_nodes: context.real_nodes,
    order_nodes: reorder_context.order_nodes,
    edge_creation_order: context.edge_creation_order,
    cluster_meta: context.cluster_meta,
    gdnlist_order: context.gdnlist_order,
    edge_tail: context.edge_tail,
    edge_head: context.edge_head,
    nodes: context.nodes,
    order_node_order: reorder_context.order_node_order,
  }
  let materialized =
    build_materialized_order_edges_and_neighbors(materialized_inputs)
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
/// Graphviz parity: root-phase tail override preserves first-seen tail order
/// while suppressing duplicate tail names in root-edge replay sequences.
/// Do not change behavior without updating fixtures/tests.
fn collect_unique_tail_order_from_edge_tail_sequence(
  edge_tail_out : Array[String],
) -> Array[String] {
  let tail_order : Array[String] = []
  let seen : Map[String, Bool] = Map::new()
  for tail in edge_tail_out {
    append_order_creation_name_if_absent(tail_order, seen, tail)
  }
  tail_order
}

///|
/// Graphviz parity: clustered root phase reuses root-only reorder input
/// assembly to derive the root-tail replay order for mapped edge materialize.
/// Do not change behavior without updating fixtures/tests.
fn build_root_tail_order_override_for_clustered_root_phase(
  stage_dispatch_context : ClusteredOrderingStageDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> (Array[String], Map[Int, Array[String]]) {
  let reorder_setup = stage_dispatch_context.reorder_setup
  let class2_data = stage_dispatch_context.class2_data
  let runtime_context = stage_dispatch_context.runtime_context
  let cluster_meta = stage_dispatch_context.cluster_meta
  let reorder_context = pre_root_stage.reorder_context
  let root_reorder_output : RootClusterReorderInputsForRankOrderOutput =
    build_root_cluster_reorder_inputs_for_rank_order(
      reorder_setup.order_with_vnodes,
      reorder_context.order_rank_keys,
      pre_root_stage.order_groups,
      pre_root_stage.order_cluster_keys,
      pre_root_stage.order_cluster_skeleton,
      stage_dispatch_context.edges,
      stage_dispatch_context.edge_tail,
      stage_dispatch_context.edge_head,
      cluster_meta.cluster_keys,
      runtime_context.vnode_info.edge_vnodes,
      runtime_context.vnode_info.vnodes_by_rank,
      reorder_setup.vnode_order_keys_for_ordering,
      class2_data.nlist_order,
      stage_dispatch_context.ranks,
      class2_data.skeleton_edge_creation,
      class2_data.root_edge_creation,
      reorder_setup.flat_rank_constraints,
      class2_data.order_edges_by_tail_root,
    )
  let (
    _root_groups,
    _root_rank_keys,
    _root_edges_out,
    root_edge_tail_out,
    _root_edge_head_out,
    _root_edge_tail_port_x,
    _root_edge_head_port_x,
    _root_edge_tail_port_order,
    _root_edge_head_port_order,
    _root_parents,
    _root_children,
    _root_edge_order,
    _root_node_order,
  ) = root_reorder_output
  let root_tail_order_override =
    collect_unique_tail_order_from_edge_tail_sequence(root_edge_tail_out)
  let dispatch_context : ClusterRankOrderFromRootReorderContext = {
    order_cluster_keys: pre_root_stage.order_cluster_keys,
    rank_same_groups: cluster_meta.rank_same_groups,
    rank_same_order: cluster_meta.rank_same_order,
    order_sizes_out: pre_root_stage.order_sizes_out,
    nodesep_pt: stage_dispatch_context.nodesep_pt,
    has_edge_labels: stage_dispatch_context.has_edge_labels,
    port_order_positions: stage_dispatch_context.port_order_positions,
    port_order_contrib: stage_dispatch_context.port_order_contrib,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
    flat_constraints: cluster_meta.flat_constraints,
    graphviz_flip: reorder_setup.graphviz_flip,
    real_nodes: runtime_context.real_nodes,
  }
  let (_root_rank_keys, ordered_root) =
    run_root_cluster_rank_order_phase_from_root_reorder_output(
      dispatch_context,
      root_reorder_output,
    )
  (root_tail_order_override, ordered_root)
}

///|
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_root_phase(
  stage_dispatch_context : ClusteredOrderingStageDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> OrderRootClusterStageData {
  let reorder_setup = stage_dispatch_context.reorder_setup
  let class2_data = stage_dispatch_context.class2_data
  let runtime_context = stage_dispatch_context.runtime_context
  remincross_root_tail_order_override_snapshot.val = None
  let (root_tail_order_override, root_groups_override) =
    build_root_tail_order_override_for_clustered_root_phase(
      stage_dispatch_context,
      pre_root_stage,
    )
  if reorder_setup.order_with_clusters {
    remincross_root_tail_order_override_snapshot.val =
      Some(root_tail_order_override.copy())
  } else {
    remincross_root_tail_order_override_snapshot.val = None
  }
  if reorder_setup.order_with_clusters &&
    @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let joined = root_tail_order_override.join(" ")
    println("remincross root_tail_order_override \{joined}")
    let gdnlist_joined = reorder_setup.gdnlist_order.join(" ")
    let nlist_joined = class2_data.nlist_order.join(" ")
    let creation_joined = pre_root_stage.reorder_context.creation_order.join(" ")
    let cluster_order_joined = stage_dispatch_context.cluster_meta.cluster_order.join(
      " ",
    )
    println("remincross source_gdnlist_order \{gdnlist_joined}")
    println("remincross source_nlist_order \{nlist_joined}")
    println("remincross source_creation_order \{creation_joined}")
    println("remincross source_cluster_order \{cluster_order_joined}")
  }
  if reorder_setup.order_with_clusters {
    root_mincross_groups_override.val =
      Some(clone_rank_groups(root_groups_override))
  } else {
    root_mincross_groups_override.val = None
  }
  let reorder_context = pre_root_stage.reorder_context
  let materialized = pre_root_stage.materialized
  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  let stage_inputs : RootClusterBuildRanksStageInputs = {
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
    order_edge_tail_port_order_unmapped: materialized.order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped: materialized.order_edge_head_port_order_unmapped,
    ordered_with_vnodes,
  }
  let output =
    run_root_and_cluster_build_ranks_stage(
      reorder_setup.order_with_clusters,
      reorder_setup.order_with_vnodes,
      stage_dispatch_context.graph,
      stage_dispatch_context.cluster_meta,
      reorder_setup.vnode_order_keys_for_ordering,
      stage_dispatch_context.nodesep_pt,
      stage_dispatch_context.has_edge_labels,
      stage_dispatch_context.port_order_positions,
      stage_dispatch_context.port_order_contrib,
      reorder_setup.graphviz_flip,
      reorder_setup.flat_rank_constraints,
      stage_dispatch_context.ranks,
      runtime_context.vnode_info,
      stage_inputs,
    )
  root_mincross_groups_override.val = None
  output
}

///|
/// Graphviz parity: clustered ordering finalize phase consumes pre-root/root
/// stage data before running cluster-rank-order + final ReMincross cleanup.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_finalize_phase(
  dispatch_context : ClusterFinalizePassDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_context = pre_root_stage.reorder_context
  let stage_inputs : ClusterFinalizeStageInputs = {
    order_rank_keys: reorder_context.order_rank_keys,
    order_groups_for_mincross: root_cluster_stage.order_groups_for_mincross,
    order_cluster_keys: pre_root_stage.order_cluster_keys,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
    order_sizes_out: pre_root_stage.order_sizes_out,
    ordered: root_cluster_stage.ordered,
    ordered_with_vnodes: root_cluster_stage.ordered_with_vnodes,
    creation_order: reorder_context.creation_order,
  }
  let (next_ordered_with_vnodes, final_groups) =
    run_cluster_rank_order_and_finalize_stage(
      dispatch_context,
      stage_inputs,
    )
  remincross_root_tail_order_override_snapshot.val = None
  (final_groups, next_ordered_with_vnodes)
}


///|
/// Graphviz parity: clustered ordering path keeps build_ranks/mincross phase
/// boundaries unchanged while delegating each phase to base helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage(
  stage_dispatch_context : ClusteredOrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let reorder_setup = stage_dispatch_context.reorder_setup
  let class2_data = stage_dispatch_context.class2_data
  let runtime_context = stage_dispatch_context.runtime_context
  let pre_root_stage_context : ClusteredOrderingPreRootStageContext = {
    ordering_groups_base: reorder_setup.ordering_groups_base,
    base_order_index: reorder_setup.base_order_index,
    order_with_vnodes: reorder_setup.order_with_vnodes,
    order_with_clusters: reorder_setup.order_with_clusters,
    cluster_meta: stage_dispatch_context.cluster_meta,
    vnode_info: runtime_context.vnode_info,
    vnode_order_keys_for_ordering: reorder_setup.vnode_order_keys_for_ordering,
    order_sizes: stage_dispatch_context.order_sizes,
    nlist_order: class2_data.nlist_order,
    gdnlist_order: reorder_setup.gdnlist_order,
    node_order: stage_dispatch_context.node_order,
    real_nodes: runtime_context.real_nodes,
    port_edge_nodes: runtime_context.port_edge_nodes,
    order_edges_by_tail: class2_data.order_edges_by_tail,
    order_edges_by_tail_unmapped: class2_data.order_edges_by_tail_unmapped,
    edge_creation_order: class2_data.edge_creation_order,
    edge_tail: stage_dispatch_context.edge_tail,
    edge_head: stage_dispatch_context.edge_head,
    nodes: stage_dispatch_context.nodes,
  }
  let pre_root_stage =
    build_clustered_ordering_pre_root_stage(pre_root_stage_context)
  let root_cluster_stage =
    run_clustered_ordering_pre_root_and_root_stage_root_phase(
      stage_dispatch_context,
      pre_root_stage,
    )
  let finalize_dispatch_context : ClusterFinalizePassDispatchContext = {
    order_with_clusters: reorder_setup.order_with_clusters,
    order_with_vnodes: reorder_setup.order_with_vnodes,
    graphviz_flip: reorder_setup.graphviz_flip,
    edges: stage_dispatch_context.edges,
    edge_tail: stage_dispatch_context.edge_tail,
    edge_head: stage_dispatch_context.edge_head,
    edge_reversed: stage_dispatch_context.edge_reversed,
    nlist_order: class2_data.nlist_order,
    ranks: stage_dispatch_context.ranks,
    order_edges_by_tail_root: class2_data.order_edges_by_tail_root,
    skeleton_edge_creation: class2_data.skeleton_edge_creation,
    root_edge_creation: class2_data.root_edge_creation,
    flat_rank_constraints: reorder_setup.flat_rank_constraints,
    cluster_meta: stage_dispatch_context.cluster_meta,
    vnode_info: runtime_context.vnode_info,
    vnode_order_keys_for_ordering: reorder_setup.vnode_order_keys_for_ordering,
    real_nodes: runtime_context.real_nodes,
    nodesep_pt: stage_dispatch_context.nodesep_pt,
    has_edge_labels: stage_dispatch_context.has_edge_labels,
    port_order_positions: stage_dispatch_context.port_order_positions,
    port_order_contrib: stage_dispatch_context.port_order_contrib,
    local_cluster_order: runtime_context.local_cluster_order,
    graph: stage_dispatch_context.graph,
    edge_tail_port_x: stage_dispatch_context.edge_port_data.edge_tail_port_x,
    edge_head_port_x: stage_dispatch_context.edge_port_data.edge_head_port_x,
    edge_tail_port_order: stage_dispatch_context.edge_port_data.edge_tail_port_order,
    edge_head_port_order: stage_dispatch_context.edge_port_data.edge_head_port_order,
    edges_by_tail: class2_data.edges_by_tail,
    order_sizes: stage_dispatch_context.order_sizes,
    rank_same_constraints: runtime_context.rank_same_constraints,
  }
  run_clustered_ordering_finalize_phase(
    finalize_dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
}
