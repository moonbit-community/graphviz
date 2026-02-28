///|
/// Stage C Phase C1 split: ordering class2
/// preprocessing helpers for order-graph construction.

///|
/// Stage C Phase C1 split: ordering edge-port/class2
/// runtime data types produced by class2 preprocessing.

///|
priv struct OrderingEdgePortData {
  edge_order : Map[String, Int]
  edge_tail_port_x : Array[Double]
  edge_head_port_x : Array[Double]
  edge_tail_port_order : Array[Double]
  edge_head_port_order : Array[Double]
  order_edges : Array[@cgraph.Edge]
  order_edge_tail : Array[String]
  order_edge_head : Array[String]
  order_edge_tail_port_x : Array[Double]
  order_edge_head_port_x : Array[Double]
  order_edge_tail_port_order : Array[Double]
  order_edge_head_port_order : Array[Double]
}

///|
priv struct OrderingClass2Data {
  edges_by_tail : Map[String, Array[Int]]
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]]
  root_edge_creation : Array[(String, String)]
  skeleton_edge_creation : Array[(String, String)]
  edge_creation_order : Array[(String, String)]
  creation_order : Array[String]
  nlist_order : Array[String]
  vnode_creation_order : Array[String]
}

///|
/// Graphviz parity: edge-port original phase keeps original edge order map and
/// per-edge port position/order arrays before any ordering-edge deduplication.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data_original_phase(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> (Map[String, Int], Array[Double], Array[Double], Array[Double], Array[Double]) {
  let edge_order = collect_edge_order(edges)
  let (edge_tail_port_x, edge_head_port_x) =
    compute_edge_port_positions(nodes, edges, edge_tail, edge_head, order_sizes)
  let (edge_tail_port_order, edge_head_port_order) =
    compute_edge_port_orders(nodes, edges, edge_tail, edge_head, order_sizes)
  (
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
  )
}


///|
/// Graphviz parity: edge-port dedup phase derives ordering-edge arrays and
/// recomputes port position/order samples on deduplicated ordering edges.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data_dedup_phase(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> (
  Array[@cgraph.Edge],
  Array[String],
  Array[String],
  Array[Double],
  Array[Double],
  Array[Double],
  Array[Double],
) {
  let (order_edges, order_edge_tail, order_edge_head) =
    dedup_ordering_edges(edges, edge_tail, edge_head)
  let (order_edge_tail_port_x, order_edge_head_port_x) =
    compute_edge_port_positions(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_sizes,
    )
  let (order_edge_tail_port_order, order_edge_head_port_order) =
    compute_edge_port_orders(
      nodes,
      order_edges,
      order_edge_tail,
      order_edge_head,
      order_sizes,
    )
  (
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  )
}


///|
/// Graphviz parity: order-graph edge arrays preserve original edge sequence,
/// then reuse deduplicated order edges for mincross-specific port sampling.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_edge_port_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  order_sizes : Map[String, NodeSize],
) -> OrderingEdgePortData {
  let (
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
  ) =
    build_ordering_edge_port_data_original_phase(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  let (
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  ) =
    build_ordering_edge_port_data_dedup_phase(
      nodes,
      edges,
      edge_tail,
      edge_head,
      order_sizes,
    )
  {
    edge_order,
    edge_tail_port_x,
    edge_head_port_x,
    edge_tail_port_order,
    edge_head_port_order,
    order_edges,
    order_edge_tail,
    order_edge_head,
    order_edge_tail_port_x,
    order_edge_head_port_x,
    order_edge_tail_port_order,
    order_edge_head_port_order,
  }
}

///|
/// Graphviz parity: root and unmapped edge chains are derived from ND_out
/// ordering after class2 edge-chain construction for clustered passes.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_root_and_unmapped_edge_chains(
  order_with_clusters : Bool,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
  creation_order : Array[String],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  cluster_keys : Map[String, String],
  edges_by_tail : Map[String, Array[Int]],
) -> (
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) {
  let (order_edges_by_tail_root, root_edge_creation) =
    build_root_order_edges_by_tail(
      order_with_clusters,
      order_edges_by_tail,
      order_edge_creation,
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      edges_by_tail,
    )
  // Graphviz parity: cluster-local build_ranks uses edge chains before
  // root/cluster remapping so local passes see original cluster endpoints.
  let order_edges_by_tail_unmapped =
    build_unmapped_order_edges_by_tail(
      order_with_clusters,
      order_edges_by_tail,
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      edges_by_tail,
    )
  (
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  )
}


///|
/// Graphviz parity: class2 base edge-chain build follows agfstnode creation
/// order and ND_out traversal before root/unmapped derivations.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_base_edge_chains(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_keys : Map[String, String],
) -> (
  Array[String],
  Map[String, Array[Int]],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
) {
  // Graphviz parity: class2 iterates agfstnode order (creation order) for edge traversal.
  let creation_order = collect_creation_order(nodes)
  // Graphviz parity: order-graph edges follow ND_out ordering after acyclic.
  let edges_by_tail =
    build_edges_by_tail_from_out_order(nodes, edge_out_order)
  let (order_edges_by_tail, vnode_creation_by_tail, order_edge_creation) =
    build_order_edges_by_tail_graphviz(
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      order_with_clusters,
      false,
      true,
      edges_by_tail,
    )
  (
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
  )
}


///|
/// Graphviz parity: class2 builds ND_out edge chains in agfstnode order,
/// then derives root/unmapped variants for clustered build_ranks passes.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_edge_chain_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_keys : Map[String, String],
) -> (
  Array[String],
  Map[String, Array[Int]],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Map[String, Array[String]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  Array[(String, String)],
  Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
) {
  let (
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
  ) =
    build_ordering_class2_base_edge_chains(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      cluster_keys,
    )
  let (
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  ) =
    build_ordering_root_and_unmapped_edge_chains(
      order_with_clusters,
      order_edges_by_tail,
      order_edge_creation,
      creation_order,
      edges,
      edge_tail,
      edge_head,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      cluster_keys,
      edges_by_tail,
    )
  (
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  )
}


///|
/// Graphviz parity: class2 creation prep builds cluster skeleton node sequence,
/// skeleton edge sequence, and merged edge creation order in pass order.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_skeleton_and_edge_creation_sequences(
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
) -> (Array[String], Array[(String, String)], Array[(String, String)]) {
  let cluster_skeleton_creation =
    build_cluster_skeleton_creation(
      order_with_clusters,
      cluster_meta.cluster_order,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
    )
  let skeleton_edge_creation =
    build_skeleton_edge_creation_for_order_graph(
      order_with_clusters,
      cluster_meta.cluster_order,
      cluster_meta.cluster_min_rank,
      cluster_meta.cluster_max_rank,
      order_edges_by_tail,
      order_edges_by_tail_root,
    )
  let edge_creation_order =
    build_edge_creation_order(
      skeleton_edge_creation,
      order_edge_creation,
    )
  (cluster_skeleton_creation, skeleton_edge_creation, edge_creation_order)
}

///|
/// Graphviz parity: class2 creation sequences build cluster skeleton edges,
/// then edge creation order and GD_nlist ordering in Graphviz pass order.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_creation_sequences(
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_edge_creation : Array[(String, String)],
  creation_order : Array[String],
  vnode_creation_by_tail : Map[String, Array[String]],
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> (Array[(String, String)], Array[(String, String)], Array[String], Array[String]) {
  let (cluster_skeleton_creation, skeleton_edge_creation, edge_creation_order) =
    build_ordering_class2_skeleton_and_edge_creation_sequences(
      order_with_clusters,
      cluster_meta,
      order_edges_by_tail,
      order_edges_by_tail_root,
      order_edge_creation,
    )
  let (nlist_order, vnode_creation_order) =
    build_nlist_order_and_vnode_creation_order(
      cluster_skeleton_creation,
      creation_order,
      vnode_creation_by_tail,
      edge_creation_order,
      flat_rank_constraints,
      graphviz_flip,
      cluster_meta.has_clusters,
      cluster_meta.cluster_keys,
    )
  (
    skeleton_edge_creation,
    edge_creation_order,
    nlist_order,
    vnode_creation_order,
  )
}


///|
/// Graphviz parity: class2 data assembly consumes edge-chain outputs, then
/// appends creation-sequence outputs without tuple field reordering.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_data_from_edge_chain_data(
  creation_order : Array[String],
  edges_by_tail : Map[String, Array[Int]],
  order_edges_by_tail : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  vnode_creation_by_tail : Map[String, Array[String]],
  order_edge_creation : Array[(String, String)],
  order_edges_by_tail_root : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  root_edge_creation : Array[(String, String)],
  order_edges_by_tail_unmapped : Map[String, Array[(String, String, Int, Bool, Double, Double, Double, Double)]],
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> OrderingClass2Data {
  let (
    skeleton_edge_creation,
    edge_creation_order,
    nlist_order,
    vnode_creation_order,
  ) =
    build_ordering_class2_creation_sequences(
      order_with_clusters,
      cluster_meta,
      order_edges_by_tail,
      order_edges_by_tail_root,
      order_edge_creation,
      creation_order,
      vnode_creation_by_tail,
      flat_rank_constraints,
      graphviz_flip,
    )
  {
    edges_by_tail,
    order_edges_by_tail,
    order_edges_by_tail_root,
    order_edges_by_tail_unmapped,
    root_edge_creation,
    skeleton_edge_creation,
    edge_creation_order,
    creation_order,
    nlist_order,
    vnode_creation_order,
  }
}


///|
/// Graphviz parity: class2/decompose ordering prep follows creation order,
/// ND_out traversal, cluster skeleton insertion, then GD_nlist construction.
/// Do not change behavior without updating fixtures/tests.
fn build_ordering_class2_data(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_out_order : Map[String, Array[Int]],
  edge_tail_port_x : Array[Double],
  edge_head_port_x : Array[Double],
  edge_tail_port_order : Array[Double],
  edge_head_port_order : Array[Double],
  ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  order_with_vnodes : Bool,
  order_with_clusters : Bool,
  cluster_meta : ClusterMetadata,
  flat_rank_constraints : Map[String, Bool],
  graphviz_flip : Bool,
) -> OrderingClass2Data {
  let (
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
  ) =
    build_ordering_class2_edge_chain_data(
      nodes,
      edges,
      edge_tail,
      edge_head,
      edge_out_order,
      edge_tail_port_x,
      edge_head_port_x,
      edge_tail_port_order,
      edge_head_port_order,
      ranks,
      edge_vnodes,
      order_with_vnodes,
      order_with_clusters,
      cluster_meta.cluster_keys,
    )
  build_ordering_class2_data_from_edge_chain_data(
    creation_order,
    edges_by_tail,
    order_edges_by_tail,
    vnode_creation_by_tail,
    order_edge_creation,
    order_edges_by_tail_root,
    root_edge_creation,
    order_edges_by_tail_unmapped,
    order_with_clusters,
    cluster_meta,
    flat_rank_constraints,
    graphviz_flip,
  )
}


///|
/// Graphviz parity: vnode ordering keys use cluster-aware class2 traversal when
/// clusters exist, otherwise GD_nlist fallback ordering for vnode ranks.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_keys_for_nonzero_vnodes(
  cluster_meta : ClusterMetadata,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  base_order_index : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  ordering_groups_base : Map[Int, Array[String]],
  nlist_order_index : Map[String, Int],
) -> Map[String, Double] {
  if cluster_meta.has_clusters {
    build_vnode_order_keys(
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      base_order_index,
      cluster_meta.cluster_keys,
      cluster_meta.cluster_parents,
      vnode_info.edge_vnodes,
      vnode_info.vnode_ranks,
    )
  } else {
    build_vnode_order_keys_from_nlist(
      ordering_groups_base,
      vnode_info.vnodes_by_rank,
      base_order_index,
      nlist_order_index,
      Map::new(),
      false,
    )
  }
}

///|
/// Graphviz parity: vnode ordering keys come from cluster-aware class2 walks,
/// or from GD_nlist fallback ordering when clusters are absent.
/// Do not change behavior without updating fixtures/tests.
fn build_vnode_order_keys_for_ordering_stage(
  vnode_count : Int,
  cluster_meta : ClusterMetadata,
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  edge_reversed : Array[Bool],
  ranks : Map[String, Int],
  base_order_index : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  ordering_groups_base : Map[Int, Array[String]],
  nlist_order_index : Map[String, Int],
) -> Map[String, Double] {
  if vnode_count > 0 {
    build_vnode_order_keys_for_nonzero_vnodes(
      cluster_meta,
      edges,
      edge_tail,
      edge_head,
      edge_reversed,
      ranks,
      base_order_index,
      vnode_info,
      ordering_groups_base,
      nlist_order_index,
    )
  } else {
    Map::new()
  }
}
