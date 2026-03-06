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
///|
/// Stage C runtime/pipeline context builders used by dispatch orchestration.

///|
priv struct OrderingRuntimeContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : @routing.EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
}

/// Graphviz parity: ordering runtime prep keeps vnode tail-constraint derivation
/// in the same position as Graphviz ordering setup, even when only used for
/// parity diagnostics.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_context(
  input : OrderingStageInput,
) -> OrderingRuntimeContext {
  let runtime_core =
    @ordering.build_ordering_runtime_core(
      {
        graph: input.graph,
        nodes: input.nodes,
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        intercluster_keys: input.cluster_meta.intercluster_keys,
        ranks: input.ranks,
        node_order: input.node_order,
      },
    )
  let vnode_info = build_edge_vnodes(
    input.nodes,
    input.edges,
    input.edge_tail,
    input.edge_head,
    input.edge_out_order,
    input.ranks,
    input.nodesep_pt,
    input.rankdir,
    runtime_core.existing_names,
    runtime_core.edge_cluster_keys,
    input.cluster_meta.cluster_parents,
  )
  // Graphviz parity: rank=same does not inject extra flat constraints at this stage.
  let rank_same_constraints : Map[String, Bool] = Map::new()
  let runtime_context : OrderingRuntimeContext =
    {
      real_nodes: runtime_core.real_nodes,
      edge_cluster_keys: runtime_core.edge_cluster_keys,
      vnode_info,
      port_edge_nodes: runtime_core.port_edge_nodes,
      local_cluster_order: runtime_core.local_cluster_order,
      rank_same_constraints,
    }
  // Graphviz parity: setup probes vnode tail constraints in setup order even
  // when the probe output is only used for parity diagnostics.
  let _ =
    if runtime_context.vnode_info.vnode_ranks.length() > 0 {
      @ordering.build_vnode_tail_constraints(
        runtime_context.vnode_info.vnodes_by_rank,
        input.edge_tail,
      )
    } else {
      Map::new()
    }
  runtime_context
}

///|
/// Graphviz parity: ordering pipeline context keeps runtime expansion, edge-port
/// extraction, and reorder-setup snapshots together for C0 dispatch/replay.
priv struct OrderingPipelineContext {
  runtime_context : OrderingRuntimeContext
  edge_port_data : @ordering.OrderingEdgePortData
  reorder_setup : @ordering.OrderingReorderSetup
}

///|
/// Graphviz parity: ordering pipeline context assembles runtime expansion,
/// edge-port snapshots, and reorder setup in the same sequence as Graphviz.
fn build_ordering_pipeline_context(
  input : OrderingStageInput,
) -> OrderingPipelineContext {
  let runtime_context =
    build_ordering_context(input)
  let edge_port_samples =
    build_edge_port_sample_bundle(
      input.nodes,
      input.edges,
      input.edge_tail,
      input.edge_head,
      input.order_sizes,
    )
  let dedup_order_edges =
    @ordering.dedup_ordering_edges(
      input.edges,
      input.edge_tail,
      input.edge_head,
    )
  let order_edge_port_samples =
    build_edge_port_sample_bundle(
      input.nodes,
      dedup_order_edges.order_edges,
      dedup_order_edges.order_edge_tail,
      dedup_order_edges.order_edge_head,
      input.order_sizes,
    )
  let edge_port_data =
    @ordering.build_ordering_edge_port_data(
      {
        edges: input.edges,
        edge_tail_port_x: edge_port_samples.tail_port_x,
        edge_head_port_x: edge_port_samples.head_port_x,
        edge_tail_port_order: edge_port_samples.tail_port_order,
        edge_head_port_order: edge_port_samples.head_port_order,
        order_edges: dedup_order_edges.order_edges,
        order_edge_tail: dedup_order_edges.order_edge_tail,
        order_edge_head: dedup_order_edges.order_edge_head,
        order_edge_tail_port_x: order_edge_port_samples.tail_port_x,
        order_edge_head_port_x: order_edge_port_samples.head_port_x,
        order_edge_tail_port_order: order_edge_port_samples.tail_port_order,
        order_edge_head_port_order: order_edge_port_samples.head_port_order,
      },
    )
  let graphviz_flip = input.rankdir == RankDir::RL || input.rankdir == RankDir::LR
  let reorder_setup =
    @ordering.build_ordering_reorder_setup(
      {
        nodes: input.nodes,
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        edge_reversed: input.edge_reversed,
        edge_out_order: input.edge_out_order,
        ranks: input.ranks,
        groups: input.groups,
        node_order: input.node_order,
        port_edge_nodes: runtime_context.port_edge_nodes,
        vnode_count: runtime_context.vnode_info.vnode_ranks.length(),
        graphviz_flip,
        has_clusters: input.cluster_meta.has_clusters,
        cluster_min_rank: input.cluster_meta.cluster_min_rank,
        cluster_max_rank: input.cluster_meta.cluster_max_rank,
        cluster_keys: input.cluster_meta.cluster_keys,
        cluster_order: input.cluster_meta.cluster_order,
        rank_same_groups: input.cluster_meta.rank_same_groups,
        rank_same_order: input.cluster_meta.rank_same_order,
        vnode_edge_vnodes: runtime_context.vnode_info.edge_vnodes,
        vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
        vnode_ranks: runtime_context.vnode_info.vnode_ranks,
        cluster_parents: input.cluster_meta.cluster_parents,
        edge_port_data,
      },
    )
  { runtime_context, edge_port_data, reorder_setup }
}
