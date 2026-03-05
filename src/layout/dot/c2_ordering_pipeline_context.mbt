///|
/// Stage C Phase C2 split: ordering runtime/pipeline context builders used by
/// C0 dispatch orchestration.

///|
priv struct OrderingRuntimeContext {
  real_nodes : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  vnode_info : @routing.EdgeVnodeInfo
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
  rank_same_constraints : Map[String, Bool]
}

///|
/// Graphviz parity: setup probes vnode tail constraints in setup order even
/// when the probe output is only used for parity diagnostics.
/// Do not change behavior without updating fixtures/tests.
fn probe_vnode_tail_constraints_for_ordering(
  vnode_info : @routing.EdgeVnodeInfo,
  edge_tail : Array[String],
) -> Unit {
  let _ =
    if vnode_info.vnode_ranks.length() > 0 {
      build_vnode_tail_constraints(vnode_info.vnodes_by_rank, edge_tail)
    } else {
      Map::new()
    }
}

///|
/// Graphviz parity: ordering runtime prep keeps vnode tail-constraint derivation
/// in the same position as Graphviz ordering setup, even when only used for
/// parity diagnostics.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_context(
  input : OrderingStageInput,
) -> OrderingRuntimeContext {
  let node_name_sets = @ordering.build_ordering_node_name_sets(input.nodes)
  let real_nodes = node_name_sets.real_nodes
  let existing_names = node_name_sets.existing_names
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(input.graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    input.nodes,
    input.edges,
    input.edge_tail,
    input.edge_head,
    input.edge_out_order,
    input.ranks,
    input.nodesep_pt,
    input.rankdir,
    existing_names,
    edge_cluster_keys,
    input.cluster_meta.cluster_parents,
  )
  let port_edge_nodes =
    @ordering.build_port_edge_nodes_for_ordering(
      input.edges,
      input.edge_tail,
      input.edge_head,
    )
  let local_cluster_order = @ordering.build_local_cluster_order(
    input.nodes,
    input.cluster_meta.intercluster_keys,
    input.ranks,
    input.node_order,
  )
  // Graphviz parity: rank=same does not inject extra flat constraints at this stage.
  let rank_same_constraints : Map[String, Bool] = Map::new()
  let runtime_context : OrderingRuntimeContext =
    {
      real_nodes,
      edge_cluster_keys,
      vnode_info,
      port_edge_nodes,
      local_cluster_order,
      rank_same_constraints,
    }
  probe_vnode_tail_constraints_for_ordering(
    runtime_context.vnode_info,
    input.edge_tail,
  )
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
/// Graphviz parity: ordering dispatch setup keeps edge-port extraction and
/// reorder setup sequence identical to Graphviz class2/mincross preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data(
  input : OrderingStageInput,
) -> @ordering.OrderingEdgePortData {
  @ordering.build_ordering_edge_port_data(
    input.nodes,
    input.edges,
    input.edge_tail,
    input.edge_head,
    input.order_sizes,
    (nodes, edges, edge_tail, edge_head, sizes) => {
      let samples =
        compute_edge_port_positions(nodes, edges, edge_tail, edge_head, sizes)
      (samples.tail_values, samples.head_values)
    },
    (nodes, edges, edge_tail, edge_head, sizes) => {
      let samples =
        compute_edge_port_orders(nodes, edges, edge_tail, edge_head, sizes)
      (samples.tail_values, samples.head_values)
    },
  )
}

///|
/// Graphviz parity: reorder setup keeps vnode-key derivation and class2 wiring
/// in the same order as Graphviz clustered/noncluster mincross preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_reorder_setup(
  input : OrderingStageInput,
  runtime_context : OrderingRuntimeContext,
  edge_port_data : @ordering.OrderingEdgePortData,
) -> @ordering.OrderingReorderSetup {
  let graphviz_flip = input.rankdir == RankDir::RL || input.rankdir == RankDir::LR
  @ordering.build_ordering_reorder_setup(
    input.nodes,
    input.edges,
    input.edge_tail,
    input.edge_head,
    input.edge_out_order,
    input.ranks,
    input.groups,
    input.node_order,
    runtime_context.port_edge_nodes,
    runtime_context.vnode_info.vnode_ranks.length(),
    graphviz_flip,
    input.cluster_meta.has_clusters,
    input.cluster_meta.cluster_min_rank,
    input.cluster_meta.cluster_max_rank,
    input.cluster_meta.cluster_keys,
    input.cluster_meta.cluster_order,
    input.cluster_meta.rank_same_groups,
    input.cluster_meta.rank_same_order,
    runtime_context.vnode_info.edge_vnodes,
    edge_port_data,
    (base_order_index) =>
      @ordering.build_vnode_order_keys(
        input.edges,
        input.edge_tail,
        input.edge_head,
        input.edge_reversed,
        input.ranks,
        base_order_index,
        input.cluster_meta.cluster_keys,
        input.cluster_meta.cluster_parents,
        runtime_context.vnode_info.edge_vnodes,
        runtime_context.vnode_info.vnode_ranks,
      ),
    (ordering_groups_base, base_order_index, nlist_order_index) =>
      build_vnode_keys_from_nlist(
        ordering_groups_base,
        runtime_context.vnode_info.vnodes_by_rank,
        base_order_index,
        nlist_order_index,
        Map::new(),
        false,
      ),
  )
}

///|
/// Graphviz parity: ordering pipeline context assembles runtime expansion,
/// edge-port snapshots, and reorder setup in the same sequence as Graphviz.
fn build_ordering_pipeline_context(
  input : OrderingStageInput,
) -> OrderingPipelineContext {
  let runtime_context =
    build_ordering_context(input)
  let edge_port_data =
    build_ordering_edge_port_data(input)
  let reorder_setup =
    build_ordering_reorder_setup(
      input,
      runtime_context,
      edge_port_data,
    )
  { runtime_context, edge_port_data, reorder_setup }
}
