///|
/// Stage C runtime/pipeline context builders used by dispatch orchestration.

///|
type OrderingRuntimeContext = @ordering.OrderingRuntimeContext

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
        intercluster_keys: input.cluster_meta.intercluster_keys,
        cluster_parents: input.cluster_meta.cluster_parents,
        edge_mid_label_metrics_for:
          edge =>
            match edge_mid_label_metrics(edge) {
              Some(value) => Some((value.width, value.height))
              None => None
            },
      },
    )
  let edge_port_samples =
    @positioning.build_edge_port_sample_bundle(
      input.nodes,
      input.edges,
      input.edge_tail,
      input.edge_head,
      input.order_sizes,
      port_offsets_for_nodes,
      edge_port_offset,
      edge_port_order,
    )
  let dedup_order_edges =
    @ordering.dedup_ordering_edges(
      input.edges,
      input.edge_tail,
      input.edge_head,
    )
  let order_edge_port_samples =
    @positioning.build_edge_port_sample_bundle(
      input.nodes,
      dedup_order_edges.order_edges,
      dedup_order_edges.order_edge_tail,
      dedup_order_edges.order_edge_head,
      input.order_sizes,
      port_offsets_for_nodes,
      edge_port_offset,
      edge_port_order,
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
