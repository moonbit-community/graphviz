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
  let stage_dispatch_context : OrderingStageDispatchContext = {
    graph: pipeline_context.graph,
    nodes: pipeline_context.nodes,
    edges: pipeline_context.edges,
    edge_tail: pipeline_context.edge_tail,
    edge_head: pipeline_context.edge_head,
    edge_reversed: pipeline_context.edge_reversed,
    edge_out_order: pipeline_context.edge_out_order,
    ranks: pipeline_context.ranks,
    rank_keys: pipeline_context.rank_keys,
    groups: pipeline_context.groups,
    node_order: pipeline_context.node_order,
    order_sizes: pipeline_context.order_sizes,
    nodesep_pt: pipeline_context.nodesep_pt,
    has_edge_labels: pipeline_context.has_edge_labels,
    cluster_meta: pipeline_context.cluster_meta,
    port_order_positions: pipeline_context.port_order_positions,
    port_order_contrib: pipeline_context.port_order_contrib,
    runtime_context: pipeline_context.runtime_context,
    dispatch_setup,
  }
  let (ordered_groups_internal, ordered_with_vnodes) =
    run_ordering_stage_dispatch(stage_dispatch_context)
  {
    ordered_groups: ordered_groups_internal,
    ordered_groups_with_vnodes: ordered_with_vnodes,
    vnode_info: pipeline_context.runtime_context.vnode_info,
    vnode_count: pipeline_context.runtime_context.vnode_count,
    order_edges: dispatch_setup.edge_port_data.order_edges,
    order_edge_tail: dispatch_setup.edge_port_data.order_edge_tail,
    order_edge_head: dispatch_setup.edge_port_data.order_edge_head,
    edge_order: dispatch_setup.edge_port_data.edge_order,
    edge_cluster_keys: pipeline_context.runtime_context.edge_cluster_keys,
    nlist_order: dispatch_setup.nlist_order,
    gdnlist_order: dispatch_setup.gdnlist_order,
    vnode_creation_order: dispatch_setup.vnode_creation_order,
  }
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
  let pipeline_context : OrderingDispatchPipelineContext = {
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
  run_ordering_dispatch_pipeline(pipeline_context)
}
