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
/// Graphviz parity: ordering pre-pass derives real-node and existing-name maps
/// directly from the graph node array before vnode creation.
/// Do not change behavior without updating fixtures/tests.
priv struct OrderingNodeNameSets {
  real_nodes : Map[String, Bool]
  existing_names : Map[String, Bool]
}

///|
/// Graphviz parity: ordering pre-pass derives real-node/existing-name sets
/// from the node array before vnode creation and class2 preparation.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_node_name_sets(
  nodes : Array[@cgraph.Node],
) -> OrderingNodeNameSets {
  let real_nodes : Map[String, Bool] = Map::new()
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    let name = node.name()
    real_nodes[name] = true
    existing_names[name] = true
  }
  { real_nodes, existing_names }
}

///|
/// Graphviz parity: explicit-port endpoints are tracked before class2 to keep
/// port-order constraints available during ordering setup.
/// Do not change behavior without updating fixtures/tests.
fn build_port_edge_nodes_for_ordering(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Map[String, Bool] {
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = @dot_shared.port_is_explicit(edge.tail_port()) ||
      @dot_shared.port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  port_edge_nodes
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
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingRuntimeContext {
  let node_name_sets = build_ordering_node_name_sets(nodes)
  let real_nodes = node_name_sets.real_nodes
  let existing_names = node_name_sets.existing_names
  let edge_cluster_keys : Map[String, String] = Map::new()
  collect_edge_cluster_keys(graph, edge_cluster_keys)
  let vnode_info = build_edge_vnodes(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    nodesep_pt,
    rankdir,
    existing_names,
    edge_cluster_keys,
    cluster_meta.cluster_parents,
  )
  let port_edge_nodes =
    build_port_edge_nodes_for_ordering(
      edges,
      edge_tail,
      edge_head,
    )
  let local_cluster_order = @ordering.build_local_cluster_order(
    nodes,
    cluster_meta.intercluster_keys,
    ranks,
    node_order,
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
  probe_vnode_tail_constraints_for_ordering(runtime_context.vnode_info, edge_tail)
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
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> @ordering.OrderingEdgePortData {
  @ordering.build_ordering_edge_port_data(
    nodes,
    edges,
    edge_tail,
    edge_head,
    order_sizes,
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
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  cluster_meta : ClusterMetadata,
  rankdir : RankDir,
  runtime_context : OrderingRuntimeContext,
  edge_port_data : @ordering.OrderingEdgePortData,
) -> @ordering.OrderingReorderSetup {
  let graphviz_flip = rankdir == RankDir::RL || rankdir == RankDir::LR
  @ordering.build_ordering_reorder_setup(
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_out_order,
    ranks,
    groups,
    node_order,
    runtime_context.port_edge_nodes,
    runtime_context.vnode_info.vnode_ranks.length(),
    graphviz_flip,
    cluster_meta.has_clusters,
    cluster_meta.cluster_min_rank,
    cluster_meta.cluster_max_rank,
    cluster_meta.cluster_keys,
    cluster_meta.cluster_order,
    cluster_meta.rank_same_groups,
    cluster_meta.rank_same_order,
    runtime_context.vnode_info.edge_vnodes,
    edge_port_data,
    (base_order_index) =>
      build_vnode_order_keys(
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        ranks,
        base_order_index,
        cluster_meta.cluster_keys,
        cluster_meta.cluster_parents,
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
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  edge_out_order : Map[String, Array[Int]],
  ranks : Map[String, Int],
  groups : Map[Int, Array[String]],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  rankdir : RankDir,
  cluster_meta : ClusterMetadata,
) -> OrderingPipelineContext {
  let runtime_context =
    build_ordering_context(
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
  let edge_port_data =
    build_ordering_edge_port_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  let reorder_setup =
    build_ordering_reorder_setup(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_out_order,
      ranks,
      groups,
      node_order,
      cluster_meta,
      rankdir,
      runtime_context,
      edge_port_data,
    )
  { runtime_context, edge_port_data, reorder_setup }
}
