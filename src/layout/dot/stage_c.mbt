///|
/// Stage C ordering stage file: contracts, runtime pipeline context, and
/// clustered/non-clustered dispatch orchestration.

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
  // Graphviz parity: ordering dispatch context captures stage-C clustered/non-
  // clustered inputs without reordering fields before dispatch execution.
  let dispatch_context : ClusteredDispatchContext =
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
  // Graphviz parity: choose clustered/non-clustered ordering flow using the
  // same flag gates as Graphviz (vnode/cluster mode).
  let dispatch_output =
    if pipeline_context.reorder_setup.order_with_vnodes ||
      pipeline_context.reorder_setup.order_with_clusters {
      // Graphviz parity: clustered ordering path keeps build_ranks/mincross
      // phase boundaries unchanged while delegating each phase to base helpers.
      let pre_root_stage = build_clustered_pre_root(dispatch_context)
      let root_phase_output =
        run_clustered_root_phase(dispatch_context, pre_root_stage)
      run_clustered_finalize_phase(
        dispatch_context,
        pre_root_stage,
        root_phase_output,
      )
    } else {
      run_nonclustered_ordering_dispatch(dispatch_context)
    }
  build_ordering_result(pipeline_context, dispatch_output)
}
