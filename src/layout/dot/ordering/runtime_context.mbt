///|
/// Ordering domain: runtime-core context used by Stage C ordering setup.

///|
/// Graphviz parity: runtime-core payload keeps real-node/name sets, edge
/// cluster keys, and order/port maps grouped before vnode expansion.
pub(all) struct OrderingRuntimeCore {
  real_nodes : Map[String, Bool]
  existing_names : Map[String, Bool]
  edge_cluster_keys : Map[String, String]
  port_edge_nodes : Map[String, Bool]
  local_cluster_order : Map[String, Int]
}

///|
/// Graphviz parity: runtime-core input keeps node/edge/rank snapshots and the
/// edge-cluster collection callback grouped in one setup boundary.
pub(all) struct BuildOrderingRuntimeCoreInput {
  nodes : Array[@cgraph.Node]
  edges : Array[@cgraph.Edge]
  edge_tail : Array[String]
  edge_head : Array[String]
  intercluster_keys : Map[String, String]
  ranks : Map[String, Int]
  node_order : Map[String, Int]
  collect_edge_cluster_keys_fn : (Map[String, String]) -> Unit
}

///|
/// Graphviz parity: ordering runtime-core setup keeps name-set build,
/// edge-cluster collection, and order/port map derivation in fixed sequence.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_runtime_core(
  input : BuildOrderingRuntimeCoreInput,
) -> OrderingRuntimeCore {
  let node_name_sets = build_ordering_node_name_sets(input.nodes)
  let real_nodes = node_name_sets.real_nodes
  let existing_names = node_name_sets.existing_names
  let edge_cluster_keys : Map[String, String] = Map::new()
  (input.collect_edge_cluster_keys_fn)(edge_cluster_keys)
  let port_edge_nodes =
    build_port_edge_nodes_for_ordering(
      input.edges,
      input.edge_tail,
      input.edge_head,
    )
  let local_cluster_order =
    build_local_cluster_order(
      input.nodes,
      input.intercluster_keys,
      input.ranks,
      input.node_order,
    )
  {
    real_nodes,
    existing_names,
    edge_cluster_keys,
    port_edge_nodes,
    local_cluster_order,
  }
}
