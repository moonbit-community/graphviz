///|
/// Stage C Phase C0 split: stage contract type
/// definitions for cluster metadata and ordering outputs.

///|
priv struct ClusterMetadata {
  has_clusters : Bool
  cluster_keys : Map[String, String]
  cluster_skeleton : Map[String, Bool]
  cluster_min_rank : Map[String, Int]
  cluster_max_rank : Map[String, Int]
  cluster_order : Array[String]
  cluster_parents : Map[String, String?]
  intercluster_keys : Map[String, String]
  rank_same_groups : Map[String, Int]
  rank_same_order : Map[String, Int]
  flat_constraints : Map[String, Bool]
  ordering_set : Bool
}

///|
priv struct OrderingResult {
  ordered_groups : Map[Int, Array[String]]
  ordered_groups_with_vnodes : Map[Int, Array[String]]
  vnode_info : EdgeVnodeInfo
  vnode_count : Int
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  edge_order : Map[String, Int]
  edge_cluster_keys : Map[String, String]
  nlist_order : Array[String]
  gdnlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
/// Stage C Phase C0 split: ordering edge/materialize
/// runtime data types shared by dispatch/setup flow.

///|
priv struct OrderingEdgePortData {
  edge_order : Map[String, Int]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
priv struct OrderingClass2Data {
  edges_by_tail : Map[String, Array[Int]]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  root_edge_creation : Array[(String, String)]
  skeleton_edge_creation : Array[(String, String)]
  edge_creation_order : Array[(String, String)]
  creation_order : Array[String]
  nlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
priv struct OrderReorderContext {
  order_rank_keys : Array[Int]
  order_ranks : Map[String, Int]
  order_nodes : Array[String]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  creation_order : Array[String]
  order_node_order : Map[String, Int]
}

///|
priv struct OrderMaterializationData {
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
  graphviz_out_neighbors : Map[String, Array[String]]
  graphviz_in_neighbors : Map[String, Array[String]]
  order_flat_constraints : Map[String, Bool]
}

///|
priv struct OrderClusteredPreRootStageData {
  order_groups : Map[Int, Array[String]]
  order_sizes_out : Map[String, NodeSize]
  order_cluster_keys : Map[String, String]
  order_cluster_skeleton : Map[String, Bool]
  reorder_context : OrderReorderContext
  materialized : OrderMaterializationData
}

///|
priv struct OrderingBaseContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
}

///|
priv struct OrderingRuntimeContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
  vnode_count : Int
}

///|
/// Stage C Phase C0 split: pre-root/materialize
/// and non-cluster stage-local type definitions.

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
/// Graphviz parity: order-edge trace materialization dispatch context keeps
/// mapped/unmapped materialize+trace payload ordering unchanged.
/// Do not change behavior without updating fixtures/tests.
priv struct MaterializeOrderEdgesWithTraceContext {
  nlist_order : Array[String]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph : @cgraph.Graph
  order_node_map : Map[String, @cgraph.Node]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_graph_unmapped : @cgraph.Graph
  order_node_map_unmapped : Map[String, @cgraph.Node]
  order_ranks : Map[String, Int]
  real_nodes : Map[String, Bool]
}

///|
/// Graphviz parity: non-cluster ordering stage dispatch context keeps
/// single-pass mincross payload ordering unchanged before stage helpers.
/// Do not change behavior without updating fixtures/tests.
priv struct NonclusterOrderingStageDispatchContext {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  nlist_order : Array[String]
  node_order : Map[String, Int]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
  cluster_meta : ClusterMetadata
  edge_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  graphviz_flip : Bool
}

///|
/// Stage C Phase C0 split: ordering input-payload
/// type definitions for compute_ordering_and_vnodes entry.

///|
/// Graphviz parity: ordering+vnode compute input payload keeps ordering/rank/
/// port fields in Graphviz compute_ordering_and_vnodes call sequence.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingAndVnodesInputs {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  rankdir : RankDir
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
/// Stage C Phase C0 split: ordering dispatch-context
/// type definitions for clustered/non-cluster branching.

///|
/// Graphviz parity: ordering-stage dispatch context keeps clustered/non-cluster
/// branch payload ordering unchanged before dispatch-stage gating.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingStageDispatchContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  dispatch_setup : OrderingDispatchSetup
}

///|
/// Graphviz parity: ordering-dispatch execution context keeps stage inputs,
/// runtime context, and dispatch setup ordering unchanged before execution.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingDispatchPipelineExecutionContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  dispatch_setup : OrderingDispatchSetup
}

///|
/// Graphviz parity: ordering-dispatch pipeline context keeps ordering/runtime
/// payload ordering unchanged before dispatch-setup + execution stages.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingDispatchPipelineContext {
  graph : @cgraph.Graph
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  edge_reversed : Array[Bool]
  edge_out_order : Map[String, Array[Int]]
  ranks : Map[String, Int]
  groups : Map[Int, Array[String]]
  rank_keys : Array[Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  rankdir : RankDir
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
}


///|
/// Stage C Phase C0 split: ordering dispatch pipeline
/// and result assembly helpers for Stage C entry flow.

///|
/// Graphviz parity: final ordering result output object maps ordering arrays,
/// vnode metadata, and edge-port-derived edge order fields unchanged.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_result_output(
  ordered_groups : Map[Int, Array[String]],
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  vnode_info : EdgeVnodeInfo,
  vnode_count : Int,
  order_edges : Array[@cgraph.Edge],
  order_edge_tail : Array[String],
  order_edge_head : Array[String],
  edge_order : Map[String, Int],
  edge_cluster_keys : Map[String, String],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  vnode_creation_order : Array[String],
) -> OrderingResult {
  {
    ordered_groups,
    ordered_groups_with_vnodes,
    vnode_info,
    vnode_count,
    order_edges,
    order_edge_tail,
    order_edge_head,
    edge_order,
    edge_cluster_keys,
    nlist_order,
    gdnlist_order,
    vnode_creation_order,
  }
}

///|
/// Graphviz parity: final ordering result must keep the exact arrays/maps produced
/// by ordering stages for downstream xpos/routing parity checks.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_result(
  ordered_groups : Map[Int, Array[String]],
  ordered_groups_with_vnodes : Map[Int, Array[String]],
  vnode_info : EdgeVnodeInfo,
  vnode_count : Int,
  edge_port_data : OrderingEdgePortData,
  edge_cluster_keys : Map[String, String],
  nlist_order : Array[String],
  gdnlist_order : Array[String],
  vnode_creation_order : Array[String],
) -> OrderingResult {
  build_ordering_result_output(
    ordered_groups,
    ordered_groups_with_vnodes,
    vnode_info,
    vnode_count,
    edge_port_data.order_edges,
    edge_port_data.order_edge_tail,
    edge_port_data.order_edge_head,
    edge_port_data.edge_order,
    edge_cluster_keys,
    nlist_order,
    gdnlist_order,
    vnode_creation_order,
  )
}

///|
/// Graphviz parity: ordering dispatch result mapping keeps runtime-context and
/// dispatch-setup arrays wired into OrderingResult without reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_result(
  ordered_groups_internal : Map[Int, Array[String]],
  ordered_with_vnodes : Map[Int, Array[String]],
  runtime_context : OrderingRuntimeContext,
  dispatch_setup : OrderingDispatchSetup,
) -> OrderingResult {
  build_ordering_result(
    ordered_groups_internal,
    ordered_with_vnodes,
    runtime_context.vnode_info,
    runtime_context.vnode_count,
    dispatch_setup.edge_port_data,
    runtime_context.edge_cluster_keys,
    dispatch_setup.nlist_order,
    dispatch_setup.gdnlist_order,
    dispatch_setup.vnode_creation_order,
  )
}

///|
/// Graphviz parity: dispatch setup uses runtime-context vnode/port fields in the
/// same order as Graphviz pre-microstep staging.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_setup_from_runtime_context(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  runtime_context : OrderingRuntimeContext,
) -> OrderingDispatchSetup {
  let setup_context : OrderingDispatchSetupContext = {
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    node_order,
    order_sizes,
    port_edge_nodes: runtime_context.port_edge_nodes,
    vnode_count: runtime_context.vnode_count,
    rankdir,
    cluster_meta,
    vnode_info: runtime_context.vnode_info,
  }
  build_ordering_dispatch_setup(setup_context)
}

///|
/// Graphviz parity: stage-dispatch context extraction reads execution payloads
/// without argument reordering before ordering stage dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_stage_dispatch_context_from_execution_context(
  execution_context : OrderingDispatchPipelineExecutionContext,
) -> OrderingStageDispatchContext {
  build_ordering_stage_dispatch_context(
    execution_context.graph,
    execution_context.nodes,
    execution_context.edges,
    execution_context.edge_tail,
    execution_context.edge_head,
    execution_context.edge_reversed,
    execution_context.edge_out_order,
    execution_context.ranks,
    execution_context.rank_keys,
    execution_context.groups,
    execution_context.node_order,
    execution_context.order_sizes,
    execution_context.nodesep_pt,
    execution_context.has_edge_labels,
    execution_context.cluster_meta,
    execution_context.port_order_positions,
    execution_context.port_order_contrib,
    execution_context.runtime_context,
    execution_context.dispatch_setup,
  )
}

///|
/// Graphviz parity: ordering dispatch stage forwards setup/runtime context
/// into clustered/non-clustered stage dispatch without argument reshuffling.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch_pipeline_stage_dispatch_phase(
  execution_context : OrderingDispatchPipelineExecutionContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let stage_dispatch_context =
    build_ordering_stage_dispatch_context_from_execution_context(
      execution_context,
    )
  run_ordering_stage_dispatch(stage_dispatch_context)
}

///|
/// Graphviz parity: ordering-dispatch execution context builder preserves
/// stage-dispatch payload ordering before execution-phase dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_execution_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  rank_keys : Array[Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  dispatch_setup : OrderingDispatchSetup,
) -> OrderingDispatchPipelineExecutionContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    rank_keys,
    groups,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    dispatch_setup,
  }
}


///|
/// Graphviz parity: ordering dispatch execution phase consumes prepared
/// dispatch setup, then maps staged outputs into OrderingResult unchanged.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch_pipeline_execution_phase(
  execution_context : OrderingDispatchPipelineExecutionContext,
) -> OrderingResult {
  let (ordered_groups_internal, ordered_with_vnodes) =
    run_ordering_dispatch_pipeline_stage_dispatch_phase(execution_context)
  build_ordering_dispatch_pipeline_result(
    ordered_groups_internal,
    ordered_with_vnodes,
    execution_context.runtime_context,
    execution_context.dispatch_setup,
  )
}


///|
/// Graphviz parity: ordering-dispatch pipeline context builder preserves
/// ordering/runtime payload ordering before pipeline execution.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_context(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
) -> OrderingDispatchPipelineContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    rank_keys,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    rankdir,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
  }
}


///|
/// Graphviz parity: ordering dispatch setup extraction reads pipeline context
/// payloads without argument reordering before setup build.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_setup_from_pipeline_context(
  pipeline_context : OrderingDispatchPipelineContext,
) -> OrderingDispatchSetup {
  build_ordering_dispatch_setup_from_runtime_context(
    pipeline_context.nodes,
    pipeline_context.edges,
    pipeline_context.edge_tail,
    pipeline_context.edge_head,
    pipeline_context.edge_reversed,
    pipeline_context.edge_out_order,
    pipeline_context.ranks,
    pipeline_context.groups,
    pipeline_context.node_order,
    pipeline_context.order_sizes,
    pipeline_context.rankdir,
    pipeline_context.cluster_meta,
    pipeline_context.runtime_context,
  )
}

///|
/// Graphviz parity: ordering dispatch execution-context extraction reads
/// pipeline context + dispatch setup without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_execution_context_from_pipeline_context(
  pipeline_context : OrderingDispatchPipelineContext,
  dispatch_setup : OrderingDispatchSetup,
) -> OrderingDispatchPipelineExecutionContext {
  build_ordering_dispatch_pipeline_execution_context(
    pipeline_context.graph,
    pipeline_context.nodes,
    pipeline_context.edges,
    pipeline_context.edge_tail,
    pipeline_context.edge_head,
    pipeline_context.edge_reversed,
    pipeline_context.edge_out_order,
    pipeline_context.ranks,
    pipeline_context.rank_keys,
    pipeline_context.groups,
    pipeline_context.node_order,
    pipeline_context.order_sizes,
    pipeline_context.nodesep_pt,
    pipeline_context.has_edge_labels,
    pipeline_context.cluster_meta,
    pipeline_context.port_order_positions,
    pipeline_context.port_order_contrib,
    pipeline_context.runtime_context,
    dispatch_setup,
  )
}

///|
/// Graphviz parity: ordering dispatch pipeline keeps setup/dispatch/result stages
/// in Graphviz-equivalent sequence while using structured runtime context.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch_pipeline(
  pipeline_context : OrderingDispatchPipelineContext,
) -> OrderingResult {
  let dispatch_setup =
    build_ordering_dispatch_setup_from_pipeline_context(pipeline_context)
  let execution_context =
    build_ordering_dispatch_pipeline_execution_context_from_pipeline_context(
      pipeline_context,
      dispatch_setup,
    )
  run_ordering_dispatch_pipeline_execution_phase(execution_context)
}


///|
/// Graphviz parity: ordering dispatch pipeline context extraction reads
/// ordering-stage inputs + runtime context without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_context_from_ordering_inputs(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
) -> OrderingDispatchPipelineContext {
  build_ordering_dispatch_pipeline_context(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    rank_keys,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    rankdir,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
  )
}


///|
/// Graphviz parity: ordering runtime-context extraction reads ordering inputs
/// without argument reordering before runtime-context assembly.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context_from_ordering_inputs(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingRuntimeContext {
  build_ordering_runtime_context_with_tail_constraints(
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    node_order,
    nodesep_pt,
    rankdir,
    cluster_meta,
  )
}


///|
/// Graphviz parity: ordering+vnode input payload assembly reads ordering stage
/// inputs without argument reordering before runtime/pipeline dispatch.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_and_vnodes_inputs(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> OrderingAndVnodesInputs {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    edge_out_order,
    ranks,
    groups,
    rank_keys,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    rankdir,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
  }
}

///|
/// Graphviz parity: runtime-context extraction from ordering+vnode payload
/// reads typed inputs without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context_from_ordering_and_vnodes_inputs(
  ordering_inputs : OrderingAndVnodesInputs,
) -> OrderingRuntimeContext {
  build_ordering_runtime_context_from_ordering_inputs(
    ordering_inputs.graph,
    ordering_inputs.nodes,
    ordering_inputs.edges,
    ordering_inputs.edge_tail,
    ordering_inputs.edge_head,
    ordering_inputs.edge_out_order,
    ordering_inputs.ranks,
    ordering_inputs.node_order,
    ordering_inputs.nodesep_pt,
    ordering_inputs.rankdir,
    ordering_inputs.cluster_meta,
  )
}

///|
/// Graphviz parity: dispatch-pipeline context extraction from ordering+vnode
/// payload keeps field ordering unchanged before pipeline execution.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_dispatch_pipeline_context_from_ordering_and_vnodes_inputs(
  ordering_inputs : OrderingAndVnodesInputs,
  runtime_context : OrderingRuntimeContext,
) -> OrderingDispatchPipelineContext {
  build_ordering_dispatch_pipeline_context_from_ordering_inputs(
    ordering_inputs.graph,
    ordering_inputs.nodes,
    ordering_inputs.edges,
    ordering_inputs.edge_tail,
    ordering_inputs.edge_head,
    ordering_inputs.edge_reversed,
    ordering_inputs.edge_out_order,
    ordering_inputs.ranks,
    ordering_inputs.groups,
    ordering_inputs.rank_keys,
    ordering_inputs.node_order,
    ordering_inputs.order_sizes,
    ordering_inputs.nodesep_pt,
    ordering_inputs.has_edge_labels,
    ordering_inputs.rankdir,
    ordering_inputs.cluster_meta,
    ordering_inputs.port_order_positions,
    ordering_inputs.port_order_contrib,
    runtime_context,
  )
}

///|
/// Graphviz parity: ordering+vnode execution consumes typed input payload and
/// preserves runtime-context + dispatch-pipeline stage ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_compute_ordering_and_vnodes_from_inputs(
  ordering_inputs : OrderingAndVnodesInputs,
) -> OrderingResult {
  let runtime_context =
    build_ordering_runtime_context_from_ordering_and_vnodes_inputs(
      ordering_inputs,
    )
  let pipeline_context =
    build_ordering_dispatch_pipeline_context_from_ordering_and_vnodes_inputs(
      ordering_inputs,
      runtime_context,
    )
  run_ordering_dispatch_pipeline(pipeline_context)
}

///|
/// Graphviz parity: ordering + vnode expansion aligned to refs/graphviz/lib/dotgen/mincross.c + dotgen/flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_ordering_and_vnodes(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  rank_keys : Array[Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
) -> OrderingResult {
  let ordering_inputs =
    build_ordering_and_vnodes_inputs(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_out_order,
      ranks,
      groups,
      rank_keys,
      node_order,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      rankdir,
      cluster_meta,
      port_order_positions,
      port_order_contrib,
    )
  run_compute_ordering_and_vnodes_from_inputs(ordering_inputs)
}

