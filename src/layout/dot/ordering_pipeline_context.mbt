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
  let vnode_info = @ordering.build_edge_vnodes(
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
    {
      edge_mid_label_metrics_for:
        edge =>
          match edge_mid_label_metrics(edge) {
            Some(value) => Some((value.width, value.height))
            None => None
          },
    },
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
