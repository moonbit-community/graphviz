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
/// Graphviz parity: ordering dispatch stage forwards setup/runtime context
/// into clustered/non-clustered stage dispatch without argument reshuffling.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch_pipeline_stage_dispatch_phase(
  execution_context : OrderingDispatchPipelineExecutionContext,
) -> (Map[Int, Array[String]], Map[Int, Array[String]]) {
  let stage_dispatch_context =
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
  build_ordering_result_output(
    ordered_groups_internal,
    ordered_with_vnodes,
    execution_context.runtime_context.vnode_info,
    execution_context.runtime_context.vnode_count,
    execution_context.dispatch_setup.edge_port_data.order_edges,
    execution_context.dispatch_setup.edge_port_data.order_edge_tail,
    execution_context.dispatch_setup.edge_port_data.order_edge_head,
    execution_context.dispatch_setup.edge_port_data.edge_order,
    execution_context.runtime_context.edge_cluster_keys,
    execution_context.dispatch_setup.nlist_order,
    execution_context.dispatch_setup.gdnlist_order,
    execution_context.dispatch_setup.vnode_creation_order,
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
/// Graphviz parity: ordering dispatch pipeline keeps setup/dispatch/result stages
/// in Graphviz-equivalent sequence while using structured runtime context.
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch_pipeline(
  pipeline_context : OrderingDispatchPipelineContext,
) -> OrderingResult {
  let setup_context : OrderingDispatchSetupContext = {
    nodes: pipeline_context.nodes,
    edges: pipeline_context.edges,
    edge_tail: pipeline_context.edge_tail,
    edge_head: pipeline_context.edge_head,
    edge_reversed: pipeline_context.edge_reversed,
    edge_out_order: pipeline_context.edge_out_order,
    ranks: pipeline_context.ranks,
    groups: pipeline_context.groups,
    node_order: pipeline_context.node_order,
    order_sizes: pipeline_context.order_sizes,
    port_edge_nodes: pipeline_context.runtime_context.port_edge_nodes,
    vnode_count: pipeline_context.runtime_context.vnode_count,
    rankdir: pipeline_context.rankdir,
    cluster_meta: pipeline_context.cluster_meta,
    vnode_info: pipeline_context.runtime_context.vnode_info,
  }
  let dispatch_setup = build_ordering_dispatch_setup(setup_context)
  let execution_context =
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
  run_ordering_dispatch_pipeline_execution_phase(execution_context)
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
  let runtime_context =
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
  let pipeline_context =
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
  run_ordering_dispatch_pipeline(pipeline_context)
}
