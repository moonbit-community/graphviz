///|
/// Stage C Phase C3/C4/C6 split: clustered ordering
/// stage-dispatch type definitions for phase orchestration.

///|
/// Graphviz parity: clustered pre-root reorder/materialization context keeps
/// stage payload ordering unchanged before reorder/materialize dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredPreRootReorderMaterializedContext {
  order_groups : Map[Int, Array[String]]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  node_order : Map[String, Int]
  real_nodes : Map[String, Bool]
  base_order_index : Map[String, Int]
  cluster_meta : ClusterMetadata
  port_edge_nodes : Map[String, Bool]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  edge_creation_order : Array[(String, String)]
  edge_tail : Array[String]
  edge_head : Array[String]
  nodes : Array[@cgraph.Node]
}

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
/// Graphviz parity: clustered ordering pre-root/root phase context keeps
/// stage setup payload ordering unchanged before stage-phase dispatch.
/// Do not change behavior without updating fixtures/tests.
priv struct ClusteredOrderingPreRootAndRootPhaseContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  reorder_setup : OrderingReorderSetup
  class2_data : OrderingClass2Data
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
/// Graphviz parity: clustered pre-root stage output object maps grouped sizes,
/// cluster skeleton keys, reorder context, and materialized edges unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_pre_root_stage_output(
  order_groups : Map[Int, Array[String]],
  order_sizes_out : Map[String, NodeSize],
  order_cluster_keys : Map[String, String],
  order_cluster_skeleton : Map[String, Bool],
  reorder_context : OrderReorderContext,
  materialized : OrderMaterializationData,
) -> OrderClusteredPreRootStageData {
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
/// Graphviz parity: clustered pre-root reorder context is built before
/// materialized order-edge/neighbor data, matching Graphviz stage sequence.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root_reorder_context_and_materialized(
  context : ClusteredPreRootReorderMaterializedContext,
) -> (OrderReorderContext, OrderMaterializationData) {
  let reorder_context =
    build_order_reorder_context(
      context.order_groups,
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
  let materialized_inputs =
    build_materialized_order_edges_and_neighbors_context(
      context.nlist_order,
      context.order_edges_by_tail,
      context.order_edges_by_tail_unmapped,
      reorder_context,
      context.real_nodes,
      context.edge_creation_order,
      context.cluster_meta,
      context.gdnlist_order,
      context.edge_tail,
      context.edge_head,
      context.nodes,
    )
  let materialized =
    build_materialized_order_edges_and_neighbors(materialized_inputs)
  (reorder_context, materialized)
}


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
  let reorder_materialized_context : ClusteredPreRootReorderMaterializedContext = {
    order_groups,
    nlist_order: context.nlist_order,
    gdnlist_order: context.gdnlist_order,
    node_order: context.node_order,
    real_nodes: context.real_nodes,
    base_order_index: context.base_order_index,
    cluster_meta: context.cluster_meta,
    port_edge_nodes: context.port_edge_nodes,
    order_edges_by_tail: context.order_edges_by_tail,
    order_edges_by_tail_unmapped: context.order_edges_by_tail_unmapped,
    edge_creation_order: context.edge_creation_order,
    edge_tail: context.edge_tail,
    edge_head: context.edge_head,
    nodes: context.nodes,
  }
  let (reorder_context, materialized) =
    build_clustered_pre_root_reorder_context_and_materialized(
      reorder_materialized_context,
    )
  build_clustered_ordering_pre_root_stage_output(
    order_groups,
    order_sizes_out,
    order_cluster_keys,
    order_cluster_skeleton,
    reorder_context,
    materialized,
  )
}


///|
/// Graphviz parity: root+cluster build_ranks stage input payload is assembled
/// from pre-root/reorder/materialized artifacts without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_root_and_cluster_build_ranks_stage_inputs_from_pre_root_payload(
  pre_root_stage : OrderClusteredPreRootStageData,
  reorder_context : OrderReorderContext,
  materialized : OrderMaterializationData,
  ordered_with_vnodes : Map[Int, Array[String]],
) -> RootClusterBuildRanksStageInputs {
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
    order_edge_tail_port_order_unmapped: materialized.order_edge_tail_port_order_unmapped,
    order_edge_head_port_order_unmapped: materialized.order_edge_head_port_order_unmapped,
    ordered_with_vnodes,
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
/// Graphviz parity: pre-root payload forwarding into root+cluster build_ranks
/// keeps reorder/materialized field mapping in Graphviz stage-call order.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_from_pre_root_payload(
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
  pre_root_stage : OrderClusteredPreRootStageData,
  reorder_context : OrderReorderContext,
  materialized : OrderMaterializationData,
) -> OrderRootClusterStageData {
  let ordered_with_vnodes : Map[Int, Array[String]] = Map::new()
  let stage_inputs_base =
    build_root_and_cluster_build_ranks_stage_inputs_from_pre_root_payload(
      pre_root_stage,
      reorder_context,
      materialized,
      ordered_with_vnodes,
    )
  let stage_inputs = stage_inputs_base
  run_root_and_cluster_build_ranks_stage(
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
    stage_inputs,
  )
}


///|
/// Graphviz parity: root + cluster build_ranks stage reads clustered pre-root
/// context directly and forwards unchanged ordering/materialized maps.
/// Do not change behavior without updating fixtures/tests.
fn run_root_and_cluster_build_ranks_stage_from_pre_root(
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
  pre_root_stage : OrderClusteredPreRootStageData,
) -> OrderRootClusterStageData {
  let reorder_context = pre_root_stage.reorder_context
  let materialized = pre_root_stage.materialized
  run_root_and_cluster_build_ranks_stage_from_pre_root_payload(
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
    pre_root_stage,
    reorder_context,
    materialized,
  )
}


///|
/// Graphviz parity: finalize-stage inputs are read directly from pre-root/root
/// stage payloads without reordering before clustered cleanup dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_finalize_stage_inputs_from_stages(
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (
  Array[Int],
  Map[Int, Array[String]],
  Map[String, String],
  Map[String, Bool],
  Map[String, NodeSize],
  Map[Int, Array[String]],
  Map[Int, Array[String]],
  Array[String],
) {
  let reorder_context = pre_root_stage.reorder_context
  (
    reorder_context.order_rank_keys,
    root_cluster_stage.order_groups_for_mincross,
    pre_root_stage.order_cluster_keys,
    pre_root_stage.order_cluster_skeleton,
    pre_root_stage.order_sizes_out,
    root_cluster_stage.ordered,
    root_cluster_stage.ordered_with_vnodes,
    reorder_context.creation_order,
  )
}


///|
/// Graphviz parity: clustered finalize-stage tuple output is unpacked into
/// named fields before forwarding to final cluster-rank-order dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_finalize_stage_inputs_from_stage_inputs_output(
  stage_inputs_output : (
    Array[Int],
    Map[Int, Array[String]],
    Map[String, String],
    Map[String, Bool],
    Map[String, NodeSize],
    Map[Int, Array[String]],
    Map[Int, Array[String]],
    Array[String],
  ),
) -> ClusterFinalizeStageInputs {
  let (
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_sizes_out,
    ordered,
    ordered_with_vnodes,
    creation_order,
  ) = stage_inputs_output
  {
    order_rank_keys,
    order_groups_for_mincross,
    order_cluster_keys,
    order_cluster_skeleton,
    order_sizes_out,
    ordered,
    ordered_with_vnodes,
    creation_order,
  }
}


///|
/// Graphviz parity: clustered finalize stage consumes root/pre-root outputs
/// without argument reordering before final cluster ReMincross.
/// Do not change behavior without updating fixtures/tests.
fn run_cluster_rank_order_and_finalize_stage_from_pre_root(
  dispatch_context : ClusterFinalizePassDispatchContext,
  pre_root_stage : OrderClusteredPreRootStageData,
  root_cluster_stage : OrderRootClusterStageData,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let stage_inputs_output =
    build_cluster_finalize_stage_inputs_from_stages(
      pre_root_stage,
      root_cluster_stage,
    )
  let stage_inputs =
    build_cluster_finalize_stage_inputs_from_stage_inputs_output(
      stage_inputs_output,
    )
  run_cluster_rank_order_and_finalize_stage(
    dispatch_context,
    stage_inputs,
  )
}


///|
/// Graphviz parity: clustered ordering root+cluster build_ranks phase consumes
/// pre-root stage payload unchanged before finalize-stage dispatch.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_root_phase(
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
  pre_root_stage : OrderClusteredPreRootStageData,
) -> OrderRootClusterStageData {
  run_root_and_cluster_build_ranks_stage_from_pre_root(
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
    pre_root_stage,
  )
}

///|
/// Graphviz parity: clustered ordering pre-root phase constructs reorder
/// context/materialized payload from ordering base inputs before root phase.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_pre_root_phase(
  nodes : Array[@cgraph.Node],
  edge_tail : Array[String],
  edge_head : Array[String],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  cluster_meta : ClusterMetadata,
  real_nodes : Map[String, Bool],
  port_edge_nodes : Map[String, Bool],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  ordering_groups_base : Map[Int, Array[String]],
  base_order_index : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  edge_creation_order : Array[(String, String)],
) -> OrderClusteredPreRootStageData {
  let pre_root_stage_context : ClusteredOrderingPreRootStageContext = {
    ordering_groups_base,
    base_order_index,
    order_with_vnodes,
    order_with_clusters,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    order_sizes,
    nlist_order,
    gdnlist_order,
    node_order,
    real_nodes,
    port_edge_nodes,
    order_edges_by_tail,
    order_edges_by_tail_unmapped,
    edge_creation_order,
    edge_tail,
    edge_head,
    nodes,
  }
  build_clustered_ordering_pre_root_stage(pre_root_stage_context)
}


///|
/// Graphviz parity: clustered ordering pre-root phase dispatch reads typed
/// stage context fields and preserves Graphviz pre-root call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_pre_root_phase_from_context(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
) -> OrderClusteredPreRootStageData {
  run_clustered_ordering_pre_root_and_root_stage_pre_root_phase(
    phase_context.nodes,
    phase_context.edge_tail,
    phase_context.edge_head,
    phase_context.node_order,
    phase_context.order_sizes,
    phase_context.cluster_meta,
    phase_context.runtime_context.real_nodes,
    phase_context.runtime_context.port_edge_nodes,
    phase_context.reorder_setup.order_with_vnodes,
    phase_context.reorder_setup.order_with_clusters,
    phase_context.reorder_setup.ordering_groups_base,
    phase_context.reorder_setup.base_order_index,
    phase_context.runtime_context.vnode_info,
    phase_context.reorder_setup.vnode_order_keys_for_ordering,
    phase_context.class2_data.nlist_order,
    phase_context.reorder_setup.gdnlist_order,
    phase_context.class2_data.order_edges_by_tail,
    phase_context.class2_data.order_edges_by_tail_unmapped,
    phase_context.class2_data.edge_creation_order,
  )
}

///|
/// Graphviz parity: clustered root phase reuses root-only reorder input
/// assembly to derive the root-tail replay order for mapped edge materialize.
/// Do not change behavior without updating fixtures/tests.
fn build_root_tail_order_override_for_clustered_root_phase(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> (Array[String], Map[Int, Array[String]]) {
  let reorder_context = pre_root_stage.reorder_context
  let root_reorder_output : RootClusterReorderInputsForRankOrderOutput =
    build_root_cluster_reorder_inputs_for_enabled_cluster_rank_order(
      phase_context.reorder_setup.order_with_vnodes,
      reorder_context.order_rank_keys,
      pre_root_stage.order_groups,
      pre_root_stage.order_cluster_keys,
      pre_root_stage.order_cluster_skeleton,
      phase_context.edges,
      phase_context.edge_tail,
      phase_context.edge_head,
      phase_context.class2_data.nlist_order,
      phase_context.ranks,
      phase_context.class2_data.skeleton_edge_creation,
      phase_context.class2_data.root_edge_creation,
      phase_context.reorder_setup.flat_rank_constraints,
      phase_context.class2_data.order_edges_by_tail_root,
      phase_context.cluster_meta,
      phase_context.runtime_context.vnode_info,
      phase_context.reorder_setup.vnode_order_keys_for_ordering,
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
    rank_same_groups: phase_context.cluster_meta.rank_same_groups,
    rank_same_order: phase_context.cluster_meta.rank_same_order,
    order_sizes_out: pre_root_stage.order_sizes_out,
    nodesep_pt: phase_context.nodesep_pt,
    has_edge_labels: phase_context.has_edge_labels,
    port_order_positions: phase_context.port_order_positions,
    port_order_contrib: phase_context.port_order_contrib,
    order_cluster_skeleton: pre_root_stage.order_cluster_skeleton,
    flat_constraints: phase_context.cluster_meta.flat_constraints,
    graphviz_flip: phase_context.reorder_setup.graphviz_flip,
    real_nodes: phase_context.runtime_context.real_nodes,
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
fn run_clustered_ordering_pre_root_and_root_stage_root_phase_from_context(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
  pre_root_stage : OrderClusteredPreRootStageData,
) -> OrderRootClusterStageData {
  remincross_root_tail_order_override_snapshot.val = None
  let (root_tail_order_override, root_groups_override) =
    build_root_tail_order_override_for_clustered_root_phase(
      phase_context,
      pre_root_stage,
    )
  if phase_context.reorder_setup.order_with_clusters {
    remincross_root_tail_order_override_snapshot.val =
      Some(root_tail_order_override.copy())
  } else {
    remincross_root_tail_order_override_snapshot.val = None
  }
  if phase_context.reorder_setup.order_with_clusters &&
    @sys.get_env_var("DOT_TRACE_REMINCROSS_INPUT") is Some(_) {
    let joined = root_tail_order_override.join(" ")
    println("remincross root_tail_order_override \{joined}")
    let gdnlist_joined = phase_context.reorder_setup.gdnlist_order.join(" ")
    let nlist_joined = phase_context.class2_data.nlist_order.join(" ")
    let creation_joined = pre_root_stage.reorder_context.creation_order.join(" ")
    let cluster_order_joined = phase_context.cluster_meta.cluster_order.join(" ")
    println("remincross source_gdnlist_order \{gdnlist_joined}")
    println("remincross source_nlist_order \{nlist_joined}")
    println("remincross source_creation_order \{creation_joined}")
    println("remincross source_cluster_order \{cluster_order_joined}")
  }
  if phase_context.reorder_setup.order_with_clusters {
    root_mincross_groups_override.val =
      Some(clone_rank_groups(root_groups_override))
  } else {
    root_mincross_groups_override.val = None
  }
  let output =
    run_clustered_ordering_pre_root_and_root_stage_root_phase(
      phase_context.reorder_setup.order_with_clusters,
      phase_context.reorder_setup.order_with_vnodes,
      phase_context.graph,
      phase_context.cluster_meta,
      phase_context.reorder_setup.vnode_order_keys_for_ordering,
      phase_context.nodesep_pt,
      phase_context.has_edge_labels,
      phase_context.port_order_positions,
      phase_context.port_order_contrib,
      phase_context.reorder_setup.graphviz_flip,
      phase_context.reorder_setup.flat_rank_constraints,
      phase_context.ranks,
      phase_context.runtime_context.vnode_info,
      pre_root_stage,
    )
  root_mincross_groups_override.val = None
  output
}

///|
/// Graphviz parity: clustered ordering pre-root/root phase execution preserves
/// Graphviz phase boundaries while forwarding through typed stage context.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_pre_root_and_root_stage_from_phase_context(
  phase_context : ClusteredOrderingPreRootAndRootPhaseContext,
) -> (OrderClusteredPreRootStageData, OrderRootClusterStageData) {
  let pre_root_stage =
    run_clustered_ordering_pre_root_and_root_stage_pre_root_phase_from_context(
      phase_context,
    )
  let root_phase_output =
    run_clustered_ordering_pre_root_and_root_stage_root_phase_from_context(
      phase_context,
      pre_root_stage,
    )
  (pre_root_stage, root_phase_output)
}

///|
/// Graphviz parity: clustered ordering finalize dispatch context preserves
/// finalize-stage payload ordering before cluster-rank-order execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_finalize_dispatch_context(
  order_with_clusters : Bool,
  order_with_vnodes : Bool,
  graphviz_flip : Bool,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  nlist_order : Array[String],
  ranks : Map[String, Int],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  skeleton_edge_creation : Array[(String, String)],
  root_edge_creation : Array[(String, String)],
  flat_rank_constraints : Map[String, Bool],
  cluster_meta : ClusterMetadata,
  vnode_info : EdgeVnodeInfo,
  vnode_order_keys_for_ordering : Map[String, Double],
  real_nodes : Map[String, Bool],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  local_cluster_order : Map[String, Int],
  graph : @cgraph.Graph,
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  edges_by_tail : Map[String, Array[Int]],
  order_sizes : Map[String, NodeSize],
  rank_same_constraints : Map[String, Bool],
) -> ClusterFinalizePassDispatchContext {
  {
    order_with_clusters,
    order_with_vnodes,
    graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    nlist_order,
    ranks,
    order_edges_by_tail_root,
    skeleton_edge_creation,
    root_edge_creation,
    flat_rank_constraints,
    cluster_meta,
    vnode_info,
    vnode_order_keys_for_ordering,
    real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    local_cluster_order,
    graph,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    edges_by_tail,
    order_sizes,
    rank_same_constraints,
  }
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
  let (next_ordered_with_vnodes, final_groups) =
    run_cluster_rank_order_and_finalize_stage_from_pre_root(
      dispatch_context,
      pre_root_stage,
      root_cluster_stage,
    )
  remincross_root_tail_order_override_snapshot.val = None
  build_clustered_ordering_stage_output(
    next_ordered_with_vnodes,
    final_groups,
  )
}


///|
/// Graphviz parity: clustered ordering pre-root/root phase context builder
/// preserves stage setup payload ordering before phase dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_pre_root_and_root_phase_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  reorder_setup : OrderingReorderSetup,
  class2_data : OrderingClass2Data,
) -> ClusteredOrderingPreRootAndRootPhaseContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    ranks,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    reorder_setup,
    class2_data,
  }
}

///|
/// Graphviz parity: clustered ordering finalize output dispatch-context
/// builder preserves finalize-phase payload ordering before stage output run.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_output_phase_dispatch_context(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  edge_port_data : OrderingEdgePortData,
  reorder_setup : OrderingReorderSetup,
  class2_data : OrderingClass2Data,
) -> ClusterFinalizePassDispatchContext {
  build_clustered_ordering_finalize_dispatch_context(
    reorder_setup.order_with_clusters,
    reorder_setup.order_with_vnodes,
    reorder_setup.graphviz_flip,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    class2_data.nlist_order,
    ranks,
    class2_data.order_edges_by_tail_root,
    class2_data.skeleton_edge_creation,
    class2_data.root_edge_creation,
    reorder_setup.flat_rank_constraints,
    cluster_meta,
    runtime_context.vnode_info,
    reorder_setup.vnode_order_keys_for_ordering,
    runtime_context.real_nodes,
    nodesep_pt,
    has_edge_labels,
    port_order_positions,
    port_order_contrib,
    runtime_context.local_cluster_order,
    graph,
    edge_port_data.edge_tail_port_x,
    edge_port_data.edge_head_port_x,
    edge_port_data.edge_tail_port_order,
    edge_port_data.edge_head_port_order,
    class2_data.edges_by_tail,
    order_sizes,
    runtime_context.rank_same_constraints,
  )
}

///|
/// Graphviz parity: clustered ordering stage dispatch context builder keeps
/// full clustered stage payload ordering unchanged before stage execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_ordering_stage_dispatch_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  edge_port_data : OrderingEdgePortData,
  reorder_setup : OrderingReorderSetup,
  class2_data : OrderingClass2Data,
) -> ClusteredOrderingStageDispatchContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    edge_port_data,
    reorder_setup,
    class2_data,
  }
}

///|
/// Graphviz parity: clustered ordering path keeps build_ranks/mincross phase
/// boundaries unchanged while delegating each phase to base helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_stage(
  stage_dispatch_context : ClusteredOrderingStageDispatchContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let phase_context = build_clustered_ordering_stage_pre_root_and_root_phase_context(
    stage_dispatch_context.graph,
    stage_dispatch_context.nodes,
    stage_dispatch_context.edges,
    stage_dispatch_context.edge_tail,
    stage_dispatch_context.edge_head,
    stage_dispatch_context.ranks,
    stage_dispatch_context.node_order,
    stage_dispatch_context.order_sizes,
    stage_dispatch_context.nodesep_pt,
    stage_dispatch_context.has_edge_labels,
    stage_dispatch_context.cluster_meta,
    stage_dispatch_context.port_order_positions,
    stage_dispatch_context.port_order_contrib,
    stage_dispatch_context.runtime_context,
    stage_dispatch_context.reorder_setup,
    stage_dispatch_context.class2_data,
  )
  let (pre_root_stage, root_cluster_stage) =
    run_clustered_ordering_pre_root_and_root_stage_from_phase_context(
      phase_context,
    )
  let finalize_dispatch_context = build_clustered_ordering_stage_output_phase_dispatch_context(
    stage_dispatch_context.graph,
    stage_dispatch_context.edges,
    stage_dispatch_context.edge_tail,
    stage_dispatch_context.edge_head,
    stage_dispatch_context.edge_reversed,
    stage_dispatch_context.ranks,
    stage_dispatch_context.order_sizes,
    stage_dispatch_context.nodesep_pt,
    stage_dispatch_context.has_edge_labels,
    stage_dispatch_context.cluster_meta,
    stage_dispatch_context.port_order_positions,
    stage_dispatch_context.port_order_contrib,
    stage_dispatch_context.runtime_context,
    stage_dispatch_context.edge_port_data,
    stage_dispatch_context.reorder_setup,
    stage_dispatch_context.class2_data,
  )
  run_clustered_ordering_finalize_phase(
    finalize_dispatch_context,
    pre_root_stage,
    root_cluster_stage,
  )
}
