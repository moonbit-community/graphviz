///|
type RankDir = @rankdir.RankDir
type NodeSize = @node_primitives.NodeSize
type ClusterMetadata = @ordering.DotClusterMetadata

///|
/// Stage C ordering stage file: contracts, runtime pipeline context, and
/// clustered/non-clustered dispatch orchestration.

///|
/// Stage C ordering owner calls stay local to the stage package; root dot only
/// passes cross-stage input payloads.

///|
/// Graphviz parity: ordering stage payload keeps rank and order-context maps
/// grouped so Stage C wiring stays explicit and stable.
pub(all) struct OrderingStageInput {
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
  port_order_positions : Map[String, Double]
  port_order_contrib : Map[String, Array[(String, Double)]]
}

///|
priv struct OrderingDispatchOutput {
  ordered_groups : Map[Int, Array[String]]
  ordered_with_vnodes : Map[Int, Array[String]]
}

///|
type OrderingPipelineContext = @ordering.OrderingPipelineContext

///|
type OrderingResult = @ordering.OrderingResult

///|
/// Graphviz parity: ordering stage output keeps cluster metadata and final
/// ordering snapshots paired so downstream stages consume the same Stage C
/// boundary artifacts from one package entry.
pub(all) struct OrderingStageOutput {
  cluster_meta : ClusterMetadata
  ordering : OrderingResult
}

///|
/// Graphviz parity: ordering stage dispatch context keeps the owner input,
/// cluster metadata, and setup pipeline artifacts grouped before clustered or
/// non-clustered dispatch execution.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingDispatchContext {
  input : OrderingStageInput
  cluster_meta : ClusterMetadata
  pipeline_context : OrderingPipelineContext
}

///|
/// Graphviz parity: non-cluster dispatch builds reorder inputs from the same
/// source payload and executes one noncluster reorder pass.
/// Do not change behavior without updating fixtures/tests.
fn run_nonclustered_ordering_dispatch(
  dispatch_context : OrderingDispatchContext,
) -> OrderingDispatchOutput {
  let input = dispatch_context.input
  let cluster_meta = dispatch_context.cluster_meta
  let pipeline_context = dispatch_context.pipeline_context
  let ordered_groups =
    @ordering.run_noncluster_reorder_pass(
      {
        nodes: input.nodes,
        edges: input.edges,
        edge_head: input.edge_head,
        edge_out_order: input.edge_out_order,
        ranks: input.ranks,
        rank_keys: input.rank_keys,
        groups: input.groups,
        node_order: input.node_order,
        cluster_keys: cluster_meta.cluster_keys,
        cluster_skeleton: cluster_meta.cluster_skeleton,
        rank_same_groups: cluster_meta.rank_same_groups,
        rank_same_order: cluster_meta.rank_same_order,
        order_sizes: input.order_sizes,
        nodesep_pt: input.nodesep_pt,
        has_edge_labels: input.has_edge_labels,
        port_order_positions: input.port_order_positions,
        port_order_contrib: input.port_order_contrib,
        flat_constraints: cluster_meta.flat_constraints,
        reorder_setup: pipeline_context.reorder_setup,
        edge_port_data: pipeline_context.edge_port_data,
      },
    )
  {
    ordered_groups,
    ordered_with_vnodes: Map::new(),
  }
}

///|
/// Stage C clustered phase helpers: pre-root, root, snapshot, and finalize.
type ClusteredPreRootData = @ordering.ClusteredPreRootStageOutput

///|
/// Graphviz parity: clustered pre-root ordering preparation keeps order-group
/// expansion, reorder context, and materialization sequence aligned to Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root(
  dispatch_context : OrderingDispatchContext,
) -> ClusteredPreRootData {
  let input = dispatch_context.input
  let cluster_meta = dispatch_context.cluster_meta
  let runtime_context = dispatch_context.pipeline_context.runtime_context
  let reorder_setup = dispatch_context.pipeline_context.reorder_setup
  @ordering.run_clustered_pre_root_stage_from_sources(
    {
      reorder_setup,
      cluster_keys: cluster_meta.cluster_keys,
      cluster_order: cluster_meta.cluster_order,
      cluster_min_rank: cluster_meta.cluster_min_rank,
      cluster_max_rank: cluster_meta.cluster_max_rank,
      vnode_clusters: runtime_context.vnode_info.vnode_clusters,
      vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
      order_sizes: input.order_sizes,
      vnode_sizes: runtime_context.vnode_info.vnode_sizes,
      // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
      skeleton_size: @node_primitives.vnode_size_from_widths(1.0, 1.0),
      node_order: input.node_order,
      real_nodes: runtime_context.real_nodes,
      has_clusters: cluster_meta.has_clusters,
      rank_same_groups: cluster_meta.rank_same_groups,
      rank_same_order: cluster_meta.rank_same_order,
      port_edge_nodes: runtime_context.port_edge_nodes,
      flat_constraints: cluster_meta.flat_constraints,
      edge_tail: input.edge_tail,
      edge_head: input.edge_head,
      nodes: input.nodes,
      intercluster_keys: cluster_meta.intercluster_keys,
    },
  )
}

///|
type ClusteredRootPhaseOutput = @ordering.ClusteredRootPhaseStageOutput

///|
/// Graphviz parity: clustered ordering root+cluster phase dispatch consumes
/// typed stage context + pre-root output without argument reordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_root_phase(
  dispatch_context : OrderingDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> ClusteredRootPhaseOutput {
  let input = dispatch_context.input
  let cluster_meta = dispatch_context.cluster_meta
  let pipeline_context = dispatch_context.pipeline_context
  let runtime_context = pipeline_context.runtime_context
  let root_phase_sources =
    @ordering.build_clustered_root_phase_stage_sources(
      {
        reorder_setup: pipeline_context.reorder_setup,
        pre_root_stage,
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        cluster_keys: cluster_meta.cluster_keys,
        edge_vnodes: runtime_context.vnode_info.edge_vnodes,
        vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
        ranks: input.ranks,
        rank_same_groups: cluster_meta.rank_same_groups,
        rank_same_order: cluster_meta.rank_same_order,
        nodesep_pt: input.nodesep_pt,
        has_edge_labels: input.has_edge_labels,
        port_order_positions: input.port_order_positions,
        port_order_contrib: input.port_order_contrib,
        graph: input.graph,
        cluster_order: cluster_meta.cluster_order,
        cluster_parents: cluster_meta.cluster_parents,
        intercluster_keys: cluster_meta.intercluster_keys,
        flat_constraints: cluster_meta.flat_constraints,
        vnode_ranks: runtime_context.vnode_info.vnode_ranks,
        vnode_clusters: runtime_context.vnode_info.vnode_clusters,
        vnode_sizes: runtime_context.vnode_info.vnode_sizes,
      },
    )
  @ordering.run_clustered_root_phase_stage_from_sources(
    root_phase_sources,
    @ordering.build_root_snapshot_capture_callback(@edge_semantics.edge_xpenalty),
  )
}

///|
/// Graphviz parity: clustered finalize phase first applies root cluster-rank
/// ordering, then runs final clustered ReMincross with unchanged call ordering.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_finalize_phase(
  dispatch_context : OrderingDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_phase_output : ClusteredRootPhaseOutput,
) -> OrderingDispatchOutput {
  let input = dispatch_context.input
  let cluster_meta = dispatch_context.cluster_meta
  let pipeline_context = dispatch_context.pipeline_context
  let runtime_context = pipeline_context.runtime_context
  let edge_port_data = pipeline_context.edge_port_data
  let finalize_sources =
    @ordering.build_clustered_finalize_stage_from_sources(
      {
        phase_base: root_phase_output.root_rank_order_phase_base,
        root_cluster_stage: root_phase_output.root_cluster_stage,
        root_tail_order_override: root_phase_output.root_tail_order_override,
        pre_root_stage,
        real_nodes: runtime_context.real_nodes,
        ratio: input.graph.get_attr("ratio").unwrap_or_default(),
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        edge_reversed: input.edge_reversed,
        edge_tail_port_x: edge_port_data.edge_tail_port_x,
        edge_head_port_x: edge_port_data.edge_head_port_x,
        edge_tail_port_order: edge_port_data.edge_tail_port_order,
        edge_head_port_order: edge_port_data.edge_head_port_order,
        ranks: input.ranks,
        reorder_setup: pipeline_context.reorder_setup,
        local_cluster_order: runtime_context.local_cluster_order,
        cluster_order: cluster_meta.cluster_order,
        cluster_keys: cluster_meta.cluster_keys,
        intercluster_keys: cluster_meta.intercluster_keys,
        cluster_parents: cluster_meta.cluster_parents,
        cluster_min_rank: cluster_meta.cluster_min_rank,
        cluster_max_rank: cluster_meta.cluster_max_rank,
        cluster_flat_constraints: cluster_meta.flat_constraints,
        rank_same_groups: cluster_meta.rank_same_groups,
        rank_same_order: cluster_meta.rank_same_order,
        edge_vnodes: runtime_context.vnode_info.edge_vnodes,
        vnode_ranks: runtime_context.vnode_info.vnode_ranks,
        vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
        vnode_sizes: runtime_context.vnode_info.vnode_sizes,
        order_sizes: input.order_sizes,
        rank_same_constraints: runtime_context.rank_same_constraints,
        root_cluster: input.graph.name().unwrap_or("__root__"),
        nodesep_pt: input.nodesep_pt,
        has_edge_labels: input.has_edge_labels,
        port_order_positions: input.port_order_positions,
        port_order_contrib: input.port_order_contrib,
      },
    )
  let finalize_output =
    @ordering.run_clustered_finalize_stage_from_root_phase_sources(
      finalize_sources,
      @ordering.build_remincross_snapshot_capture_callback(
        @edge_semantics.edge_xpenalty,
      ),
      @ordering.run_remincross_cleanup_reorder,
    )
  {
    ordered_groups: finalize_output.ordered_groups,
    ordered_with_vnodes: finalize_output.ordered_with_vnodes,
  }
}

///|
/// Graphviz parity: clustered ordering dispatch keeps pre-root/root/finalize
/// stage sequencing unchanged while delegating each phase to dedicated helpers.
/// Do not change behavior without updating fixtures/tests.
fn run_clustered_ordering_dispatch(
  dispatch_context : OrderingDispatchContext,
) -> OrderingDispatchOutput {
  let pre_root_stage = build_clustered_pre_root(dispatch_context)
  let root_phase_output =
    run_clustered_root_phase(dispatch_context, pre_root_stage)
  run_clustered_finalize_phase(
    dispatch_context,
    pre_root_stage,
    root_phase_output,
  )
}

///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the
/// same flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch(
  dispatch_context : OrderingDispatchContext,
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.pipeline_context.reorder_setup
  if reorder_setup.order_with_vnodes || reorder_setup.order_with_clusters {
    run_clustered_ordering_dispatch(dispatch_context)
  } else {
    run_nonclustered_ordering_dispatch(dispatch_context)
  }
}


///|
/// Graphviz parity: ordering + vnode expansion aligned to refs/graphviz/lib/dotgen/mincross.c + dotgen/flat.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
pub fn compute_ordering_stage(
  input : OrderingStageInput,
) -> OrderingStageOutput {
  let cluster_meta =
    @ordering.build_dot_cluster_metadata_from_sources(
      {
        graph: input.graph,
        nodes: input.nodes,
        edges: input.edges,
        groups: input.groups,
        ranks: input.ranks,
        node_order: input.node_order,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        rankdir: input.rankdir,
      },
    )
  let build_port_sample_bundle =
    (edges, edge_tail, edge_head) =>
      @port_bridge.build_edge_port_sample_bundle(
        input.nodes,
        edges,
        edge_tail,
        edge_head,
        input.order_sizes,
      )
  let pipeline_context =
    @ordering.build_ordering_pipeline_context_from_sources(
      {
        graph: input.graph,
        nodes: input.nodes,
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
        edge_reversed: input.edge_reversed,
        edge_out_order: input.edge_out_order,
        ranks: input.ranks,
        groups: input.groups,
        node_order: input.node_order,
        nodesep_pt: input.nodesep_pt,
        rankdir: input.rankdir,
        cluster_meta,
      },
      build_port_sample_bundle,
    )
  let dispatch_output =
    run_ordering_dispatch(
      {
        input,
        cluster_meta,
        pipeline_context,
      },
    )
  {
    cluster_meta,
    ordering:
      @ordering.build_ordering_result_from_pipeline_context(
        pipeline_context,
        dispatch_output.ordered_groups,
        dispatch_output.ordered_with_vnodes,
      ),
  }
}
