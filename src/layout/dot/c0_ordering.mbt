///|
/// Stage C Phase C0 split: stage contract type
/// definitions for cluster metadata and ordering outputs.

///|
/// Graphviz parity: ordering stage payload keeps rank and order-context maps
/// grouped so Stage C wiring stays explicit and stable.
priv struct OrderingStageInput {
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
priv struct OrderingDispatchOutput {
  ordered_groups : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

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
  vnode_info : @routing.EdgeVnodeInfo
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
/// Stage C Phase C3 split: clustered ordering
/// stage-dispatch type definitions for pre-root orchestration.

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
  edge_out_order : Map[String, Array[Int]]
  rank_keys : Array[Int]
  groups : Map[Int, Array[String]]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  order_sizes : Map[String, NodeSize]
  nodesep_pt : Double
  has_edge_labels : Bool
  cluster_meta : ClusterMetadata
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
  runtime_context : OrderingRuntimeContext
  edge_port_data : @ordering.OrderingEdgePortData
  reorder_setup : @ordering.OrderingReorderSetup
}

///|
/// Graphviz parity: clustered ordering path keeps build_ranks/mincross phase
/// boundaries unchanged while delegating each phase to base helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered(
  dispatch_context : ClusteredDispatchContext,
) -> OrderingDispatchOutput {
  let pre_root_stage = build_clustered_pre_root(dispatch_context)
  let root_phase_output = run_clustered_root_phase(dispatch_context, pre_root_stage)
  run_clustered_finalize_phase(
    dispatch_context,
    pre_root_stage,
    root_phase_output,
  )
}


///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the same
/// flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch(
  dispatch_context : ClusteredDispatchContext,
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
  if reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters {
    run_clustered(dispatch_context)
  } else {
    run_nonclustered_ordering_dispatch(dispatch_context)
  }
}


///|
/// Graphviz parity: non-cluster dispatch builds reorder inputs from the same
/// source payload and executes one noncluster reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn run_nonclustered_ordering_dispatch(
  dispatch_context : ClusteredDispatchContext,
) -> OrderingDispatchOutput {
  let noncluster_inputs =
    @ordering.build_noncluster_reorder_inputs_from_sources(
      {
        nodes: dispatch_context.nodes,
        edges: dispatch_context.edges,
        edge_head: dispatch_context.edge_head,
        edge_out_order: dispatch_context.edge_out_order,
        ranks: dispatch_context.ranks,
        rank_keys: dispatch_context.rank_keys,
        groups: dispatch_context.groups,
        node_order: dispatch_context.node_order,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        cluster_skeleton: dispatch_context.cluster_meta.cluster_skeleton,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        order_sizes: dispatch_context.order_sizes,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        flat_constraints: dispatch_context.cluster_meta.flat_constraints,
        reorder_setup: dispatch_context.reorder_setup,
        edge_port_data: dispatch_context.edge_port_data,
      },
    )
  let ordered_groups =
    @ordering.run_noncluster_reorder_pass(noncluster_inputs)
  {
    ordered_groups,
    ordered_with_vnodes: Map::new(),
  }
}

///|
/// Graphviz parity: ordering dispatch context captures stage-C clustered/non-
/// clustered inputs without reordering fields before dispatch execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_dispatch_context(
  input : OrderingStageInput,
  pipeline_context : OrderingPipelineContext,
) -> ClusteredDispatchContext {
  {
    graph: input.graph,
    nodes: input.nodes,
    edges: input.edges,
    edge_tail: input.edge_tail,
    edge_head: input.edge_head,
    edge_reversed: input.edge_reversed,
    edge_out_order: input.edge_out_order,
    rank_keys: input.rank_keys,
    groups: input.groups,
    ranks: input.ranks,
    node_order: input.node_order,
    order_sizes: input.order_sizes,
    nodesep_pt: input.nodesep_pt,
    has_edge_labels: input.has_edge_labels,
    cluster_meta: input.cluster_meta,
    port_order_positions: input.port_order_positions,
    port_order_contrib: input.port_order_contrib,
    runtime_context: pipeline_context.runtime_context,
    edge_port_data: pipeline_context.edge_port_data,
    reorder_setup: pipeline_context.reorder_setup,
  }
}

///|
/// Graphviz parity: ordering result assembly forwards dispatch and pipeline
/// snapshots in Graphviz-aligned field composition order.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_result(
  pipeline_context : OrderingPipelineContext,
  dispatch_output : OrderingDispatchOutput,
) -> OrderingResult {
  {
    ordered_groups: dispatch_output.ordered_groups,
    ordered_groups_with_vnodes: dispatch_output.ordered_with_vnodes,
    vnode_info: pipeline_context.runtime_context.vnode_info,
    vnode_count: pipeline_context.runtime_context.vnode_info.vnode_ranks.length(),
    order_edges: pipeline_context.edge_port_data.order_edges,
    order_edge_tail: pipeline_context.edge_port_data.order_edge_tail,
    order_edge_head: pipeline_context.edge_port_data.order_edge_head,
    edge_order: pipeline_context.edge_port_data.edge_order,
    edge_cluster_keys: pipeline_context.runtime_context.edge_cluster_keys,
    nlist_order: pipeline_context.reorder_setup.class2_data.nlist_order,
    gdnlist_order: pipeline_context.reorder_setup.gdnlist_order,
    vnode_creation_order:
      pipeline_context.reorder_setup.class2_data.vnode_creation_order,
  }
}


///|
/// Graphviz parity: ordering + vnode expansion aligned to refs/graphviz/lib/dotgen/mincross.c + dotgen/flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_ordering_and_vnodes(
  input : OrderingStageInput,
) -> OrderingResult {
  let pipeline_context =
    build_ordering_pipeline_context(input)
  let dispatch_context =
    build_clustered_dispatch_context(
      input,
      pipeline_context,
    )
  let dispatch_output =
    run_ordering_dispatch(dispatch_context)
  build_ordering_result(pipeline_context, dispatch_output)
}
