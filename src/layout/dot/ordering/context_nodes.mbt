///|
/// Ordering domain: runtime context node/port seed helpers used by Stage C
/// pipeline setup before vnode expansion.

///|
/// Graphviz parity: ordering pre-pass derives real-node and existing-name maps
/// directly from the graph node array before vnode creation.
/// Do not change behavior without updating fixtures/tests.
pub(all) struct OrderingNodeNameSets {
  real_nodes : Map[String, Bool]
  existing_names : Map[String, Bool]
}

///|
/// Graphviz parity: ordering pre-pass derives real-node/existing-name sets
/// from the node array before vnode creation and class2 preparation.
/// Do not change behavior without updating fixtures/tests.
pub fn build_ordering_node_name_sets(
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
pub fn build_port_edge_nodes_for_ordering(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Map[String, Bool] {
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = @edge_identity.port_is_explicit(edge.tail_port()) ||
      @edge_identity.port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  port_edge_nodes
}
