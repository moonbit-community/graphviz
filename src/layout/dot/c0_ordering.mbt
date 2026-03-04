///|
/// Stage C Phase C0 split: stage contract type
/// definitions for cluster metadata and ordering outputs.

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
/// Graphviz parity: clustered dispatch context preserves ordering payload shape
/// before stage dispatch, including class2 snapshots from reorder setup.
/// Do not change behavior without updating fixtures/tests.
fn build_clustered_dispatch_context_for_ordering(
  graph : @cgraph.Graph,
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  node_order : Map[String, Int],
  order_sizes : Map[String, NodeSize],
  nodesep_pt : Double,
  has_edge_labels : Bool,
  cluster_meta : ClusterMetadata,
  port_order_positions : Map[String, Double],
  port_order_contrib : Map[String, Array[(String, Double)]],
  runtime_context : OrderingRuntimeContext,
  edge_port_data : @ordering.OrderingEdgePortData,
  reorder_setup : @ordering.OrderingReorderSetup,
) -> ClusteredDispatchContext {
  {
    graph,
    nodes,
    edges,
    edge_tail,
    edge_head,
    edge_reversed,
    ranks,
    node_order,
    order_sizes,
    nodesep_pt,
    has_edge_labels,
    cluster_meta,
    port_order_positions,
    port_order_contrib,
    runtime_context,
    edge_port_data,
    reorder_setup,
  }
}

///|
/// Graphviz parity: ordering result payload preserves stage-dispatch outputs
/// and class2/vnode snapshots used by downstream layout phases.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_result(
  dispatch_output : OrderingDispatchOutput,
  pipeline_context : OrderingPipelineContext,
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
  let pipeline_context =
    build_ordering_pipeline_context(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      edge_out_order,
      ranks,
      groups,
      node_order,
      order_sizes,
      nodesep_pt,
      rankdir,
      cluster_meta,
    )
  let dispatch_context =
    build_clustered_dispatch_context_for_ordering(
      graph,
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      node_order,
      order_sizes,
      nodesep_pt,
      has_edge_labels,
      cluster_meta,
      port_order_positions,
      port_order_contrib,
      pipeline_context.runtime_context,
      pipeline_context.edge_port_data,
      pipeline_context.reorder_setup,
    )
  let dispatch_output =
    run_ordering_dispatch(
      dispatch_context,
      edge_out_order,
      rank_keys,
      groups,
    )
  build_ordering_result(
    dispatch_output,
    pipeline_context,
  )
}
