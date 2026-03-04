///|
/// Stage C Phase C0 split: ordering setup-stage
/// type definitions for reorder/materialize preparation.

///|
/// Stage C Phase C0 split: ordering runtime
/// context type for pre-class2 setup derivation.

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
/// Stage C Phase C0 split: ordering setup context
/// and dispatch preparation helpers.

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
