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
  vnode_info : EdgeVnodeInfo
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
/// Graphviz parity: ordering result bundles dispatch output together with vnode
/// expansion artifacts and class2/GD_nlist snapshots for later stages.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_result(
  runtime_context : OrderingRuntimeContext,
  dispatch_setup : OrderingDispatchSetup,
  dispatch_output : OrderingDispatchOutput,
) -> OrderingResult {
  {
    ordered_groups: dispatch_output.ordered_groups,
    ordered_groups_with_vnodes: dispatch_output.ordered_with_vnodes,
    vnode_info: runtime_context.vnode_info,
    vnode_count: runtime_context.vnode_count,
    order_edges: dispatch_setup.edge_port_data.order_edges,
    order_edge_tail: dispatch_setup.edge_port_data.order_edge_tail,
    order_edge_head: dispatch_setup.edge_port_data.order_edge_head,
    edge_order: dispatch_setup.edge_port_data.edge_order,
    edge_cluster_keys: runtime_context.edge_cluster_keys,
    nlist_order: dispatch_setup.nlist_order,
    gdnlist_order: dispatch_setup.gdnlist_order,
    vnode_creation_order: dispatch_setup.vnode_creation_order,
  }
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
  let dispatch_setup =
    build_ordering_dispatch_setup(
      {
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
        port_edge_nodes: runtime_context.port_edge_nodes,
        vnode_count: runtime_context.vnode_count,
        rankdir,
        cluster_meta,
        vnode_info: runtime_context.vnode_info,
      },
    )
  let dispatch_output =
    run_ordering_dispatch(
      {
        graph,
        nodes,
        edges,
        edge_tail,
        edge_head,
        edge_reversed,
        edge_out_order,
        ranks,
        rank_keys,
        groups,
        node_order,
        order_sizes,
        nodesep_pt,
        has_edge_labels,
        cluster_meta,
        port_order_positions,
        port_order_contrib,
        runtime_context,
        dispatch_setup,
      },
    )
  build_ordering_result(runtime_context, dispatch_setup, dispatch_output)
}
