///|
type RankDir = @rankdir.RankDir
type NodeSize = @node_primitives.NodeSize
type ClusterMetadata = @ordering.DotClusterMetadata
type EdgePortSampleBundle = @ordering.EdgePortSampleBundle

///|
/// Stage C ordering stage file: contracts, runtime pipeline context, and
/// clustered/non-clustered dispatch orchestration.

///|
/// Graphviz parity: Stage C dependency payload keeps root-owned geometry and
/// label-metric bridges explicit while the subpackage owns ordering dispatch.
pub(all) struct OrderingStageDeps {
  edge_mid_label_metrics_for : (@cgraph.Edge) -> (Double, Double)?
  build_edge_port_sample_bundle : (
    Array[@cgraph.Node],
    Array[@cgraph.Edge],
    Array[String],
    Array[String],
    Map[String, NodeSize],
  ) -> EdgePortSampleBundle
}

///|
/// Graphviz parity: Stage C default deps live with the owning stage package so
/// Stage B only wires cross-stage inputs while label/port bridge behavior stays
/// centralized here.
fn build_ordering_stage_deps() -> OrderingStageDeps {
  {
    edge_mid_label_metrics_for: edge =>
      match @edge_label_metrics.edge_mid_label_metrics(edge) {
        Some(value) => Some((value.width, value.height))
        None => None
      },
    build_edge_port_sample_bundle:
      (nodes, edges, edge_tail, edge_head, order_sizes) =>
        @positioning.build_edge_port_sample_bundle(
          nodes,
          edges,
          edge_tail,
          edge_head,
          order_sizes,
          @port_bridge.port_offsets_for_nodes,
          @port_bridge.edge_port_offset,
          @port_bridge.edge_port_order,
        ),
  }
}

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
type OrderingRuntimeContext = @ordering.OrderingRuntimeContext

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
/// Graphviz parity: ordering pipeline context keeps runtime expansion, edge-port
/// extraction, and reorder-setup snapshots together for C0 dispatch/replay.
priv struct OrderingPipelineContext {
  runtime_context : OrderingRuntimeContext
  edge_port_data : @ordering.OrderingEdgePortData
  reorder_setup : @ordering.OrderingReorderSetup
}

///|
/// Graphviz parity: ordering stage first derives cluster metadata from rank
/// groups and edge endpoint snapshots before any vnode/runtime expansion.
/// Do not change behavior without updating fixtures/tests.
fn build_cluster_metadata(input : OrderingStageInput) -> ClusterMetadata {
  @ordering.build_dot_cluster_metadata(
    {
      graph: input.graph,
      nodes: input.nodes,
      edges: input.edges,
      groups: input.groups,
      ranks: input.ranks,
      node_order: input.node_order,
      edge_tail: input.edge_tail,
      edge_head: input.edge_head,
      graphviz_flip: input.rankdir == RankDir::LR || input.rankdir == RankDir::RL,
    },
  )
}

///|
/// Graphviz parity: ordering runtime context assembly keeps vnode expansion and
/// cluster edge wiring aligned with Graphviz preprocessing sequence.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_runtime_context(
  input : OrderingStageInput,
  cluster_meta : ClusterMetadata,
  deps : OrderingStageDeps,
) -> OrderingRuntimeContext {
  @ordering.build_ordering_runtime_context(
    {
      graph: input.graph,
      nodes: input.nodes,
      edges: input.edges,
      edge_tail: input.edge_tail,
      edge_head: input.edge_head,
      edge_out_order: input.edge_out_order,
      ranks: input.ranks,
      node_order: input.node_order,
      nodesep_pt: input.nodesep_pt,
      rankdir: input.rankdir,
      intercluster_keys: cluster_meta.intercluster_keys,
      cluster_parents: cluster_meta.cluster_parents,
      edge_mid_label_metrics_for: deps.edge_mid_label_metrics_for,
    },
  )
}

///|
/// Graphviz parity: ordering pipeline context assembles runtime expansion,
/// edge-port snapshots, and reorder setup in the same sequence as Graphviz.
fn build_ordering_pipeline_context(
  input : OrderingStageInput,
  cluster_meta : ClusterMetadata,
  deps : OrderingStageDeps,
) -> OrderingPipelineContext {
  let runtime_context = build_ordering_runtime_context(input, cluster_meta, deps)
  let build_port_sample_bundle =
    (edges, edge_tail, edge_head) =>
      (deps.build_edge_port_sample_bundle)(
        input.nodes,
        edges,
        edge_tail,
        edge_head,
        input.order_sizes,
      )
  let edge_port_data =
    @ordering.build_ordering_edge_port_data_from_sources(
      {
        edges: input.edges,
        edge_tail: input.edge_tail,
        edge_head: input.edge_head,
      },
      { build_port_sample_bundle: build_port_sample_bundle },
    )
  let reorder_setup =
    @ordering.build_ordering_reorder_setup_from_sources(
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
        runtime_context,
        cluster_meta,
        rankdir: input.rankdir,
        edge_port_data,
      },
    )
  { runtime_context, edge_port_data, reorder_setup }
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
/// Stage C clustered phase helpers: pre-root, root, snapshot, and finalize.
type ClusteredPreRootData = @ordering.ClusteredPreRootStageOutput

///|
/// Graphviz parity: clustered pre-root ordering preparation keeps order-group
/// expansion, reorder context, and materialization sequence aligned to Graphviz.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_pre_root(
  dispatch_context : ClusteredDispatchContext,
) -> ClusteredPreRootData {
  let runtime_context = dispatch_context.runtime_context
  @ordering.run_clustered_pre_root_stage_from_sources(
    {
      reorder_setup: dispatch_context.reorder_setup,
      cluster_keys: dispatch_context.cluster_meta.cluster_keys,
      cluster_order: dispatch_context.cluster_meta.cluster_order,
      cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
      cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
      vnode_clusters: runtime_context.vnode_info.vnode_clusters,
      vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
      order_sizes: dispatch_context.order_sizes,
      vnode_sizes: runtime_context.vnode_info.vnode_sizes,
      // Graphviz parity: cluster skeleton vnodes use virtual_node() defaults.
      skeleton_size: @node_primitives.vnode_size_from_widths(1.0, 1.0),
      node_order: dispatch_context.node_order,
      real_nodes: runtime_context.real_nodes,
      has_clusters: dispatch_context.cluster_meta.has_clusters,
      rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
      rank_same_order: dispatch_context.cluster_meta.rank_same_order,
      port_edge_nodes: runtime_context.port_edge_nodes,
      flat_constraints: dispatch_context.cluster_meta.flat_constraints,
      edge_tail: dispatch_context.edge_tail,
      edge_head: dispatch_context.edge_head,
      nodes: dispatch_context.nodes,
      intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
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
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
) -> ClusteredRootPhaseOutput {
  let reorder_setup = dispatch_context.reorder_setup
  let runtime_context = dispatch_context.runtime_context
  let root_phase_sources =
    @ordering.build_clustered_root_phase_stage_sources(
      {
        reorder_setup,
        pre_root_stage,
        edges: dispatch_context.edges,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        edge_vnodes: runtime_context.vnode_info.edge_vnodes,
        vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
        ranks: dispatch_context.ranks,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
        graph: dispatch_context.graph,
        cluster_order: dispatch_context.cluster_meta.cluster_order,
        cluster_parents: dispatch_context.cluster_meta.cluster_parents,
        intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
        flat_constraints: dispatch_context.cluster_meta.flat_constraints,
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
  dispatch_context : ClusteredDispatchContext,
  pre_root_stage : ClusteredPreRootData,
  root_phase_output : ClusteredRootPhaseOutput,
) -> OrderingDispatchOutput {
  let runtime_context = dispatch_context.runtime_context
  let finalize_sources =
    @ordering.build_clustered_finalize_stage_from_sources(
      {
        phase_base: root_phase_output.root_rank_order_phase_base,
        root_cluster_stage: root_phase_output.root_cluster_stage,
        root_tail_order_override: root_phase_output.root_tail_order_override,
        pre_root_stage,
        real_nodes: runtime_context.real_nodes,
        ratio: dispatch_context.graph.get_attr("ratio").unwrap_or_default(),
        edges: dispatch_context.edges,
        edge_tail: dispatch_context.edge_tail,
        edge_head: dispatch_context.edge_head,
        edge_reversed: dispatch_context.edge_reversed,
        edge_tail_port_x: dispatch_context.edge_port_data.edge_tail_port_x,
        edge_head_port_x: dispatch_context.edge_port_data.edge_head_port_x,
        edge_tail_port_order: dispatch_context.edge_port_data.edge_tail_port_order,
        edge_head_port_order: dispatch_context.edge_port_data.edge_head_port_order,
        ranks: dispatch_context.ranks,
        reorder_setup: dispatch_context.reorder_setup,
        local_cluster_order: runtime_context.local_cluster_order,
        cluster_order: dispatch_context.cluster_meta.cluster_order,
        cluster_keys: dispatch_context.cluster_meta.cluster_keys,
        intercluster_keys: dispatch_context.cluster_meta.intercluster_keys,
        cluster_parents: dispatch_context.cluster_meta.cluster_parents,
        cluster_min_rank: dispatch_context.cluster_meta.cluster_min_rank,
        cluster_max_rank: dispatch_context.cluster_meta.cluster_max_rank,
        cluster_flat_constraints: dispatch_context.cluster_meta.flat_constraints,
        rank_same_groups: dispatch_context.cluster_meta.rank_same_groups,
        rank_same_order: dispatch_context.cluster_meta.rank_same_order,
        edge_vnodes: runtime_context.vnode_info.edge_vnodes,
        vnode_ranks: runtime_context.vnode_info.vnode_ranks,
        vnodes_by_rank: runtime_context.vnode_info.vnodes_by_rank,
        vnode_sizes: runtime_context.vnode_info.vnode_sizes,
        order_sizes: dispatch_context.order_sizes,
        rank_same_constraints: runtime_context.rank_same_constraints,
        root_cluster: dispatch_context.graph.name().unwrap_or("__root__"),
        nodesep_pt: dispatch_context.nodesep_pt,
        has_edge_labels: dispatch_context.has_edge_labels,
        port_order_positions: dispatch_context.port_order_positions,
        port_order_contrib: dispatch_context.port_order_contrib,
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
  dispatch_context : ClusteredDispatchContext,
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
/// Graphviz parity: ordering dispatch context captures stage-C clustered/non-
/// clustered inputs without reordering fields before dispatch execution.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_dispatch_context(
  input : OrderingStageInput,
  cluster_meta : ClusterMetadata,
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
    cluster_meta,
    port_order_positions: input.port_order_positions,
    port_order_contrib: input.port_order_contrib,
    runtime_context: pipeline_context.runtime_context,
    edge_port_data: pipeline_context.edge_port_data,
    reorder_setup: pipeline_context.reorder_setup,
  }
}

///|
/// Graphviz parity: choose clustered/non-clustered ordering flow using the
/// same flag gates as Graphviz (vnode/cluster mode).
/// Do not change behavior without updating fixtures/tests.
fn run_ordering_dispatch(
  dispatch_context : ClusteredDispatchContext,
) -> OrderingDispatchOutput {
  let reorder_setup = dispatch_context.reorder_setup
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
  deps? : OrderingStageDeps = build_ordering_stage_deps(),
) -> OrderingStageOutput {
  let cluster_meta = build_cluster_metadata(input)
  let pipeline_context =
    build_ordering_pipeline_context(input, cluster_meta, deps)
  let dispatch_context =
    build_clustered_dispatch_context(input, cluster_meta, pipeline_context)
  let dispatch_output =
    run_ordering_dispatch(dispatch_context)
  {
    cluster_meta,
    ordering: build_ordering_result(pipeline_context, dispatch_output),
  }
}
