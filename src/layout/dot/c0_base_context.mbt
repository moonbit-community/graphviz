///|
/// Stage C Phase C0 split: shared ordering base-context
/// and position-name helpers for dispatch setup.

///|
/// Graphviz parity: existing-name map is seeded from declared nodes before
/// vnode synthesis and flat-label augmentation overlays.
/// Do not change behavior without updating fixtures/tests.
fn build_existing_node_names_map_for_positions(
  nodes : Array[@cgraph.Node],
) -> Map[String, Bool] {
  let existing_names : Map[String, Bool] = Map::new()
  for node in nodes {
    existing_names[node.name()] = true
  }
  existing_names
}

///|
/// Graphviz parity: vnode names are overlaid onto existing-name maps before
/// helper calls that need collision-safe synthetic node naming.
/// Do not change behavior without updating fixtures/tests.
fn add_vnode_names_to_existing_names_for_positions(
  existing_names : Map[String, Bool],
  vnode_ranks : Map[String, Int],
) -> Unit {
  for vnode, _ in vnode_ranks {
    existing_names[vnode] = true
  }
}

///|
/// Graphviz parity: ordering base-context port-edge map marks both endpoints
/// for edges with explicit tail/head ports before rank-same constraints build.
/// Do not change behavior without updating fixtures/tests.
fn build_port_edge_nodes_for_ordering_base_context(
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> Map[String, Bool] {
  let port_edge_nodes : Map[String, Bool] = Map::new()
  for edge_idx in 0..<edges.length() {
    let edge = edges[edge_idx]
    let ported = port_is_explicit(edge.tail_port()) ||
      port_is_explicit(edge.head_port())
    if ported {
      port_edge_nodes[edge_tail[edge_idx]] = true
      port_edge_nodes[edge_head[edge_idx]] = true
    }
  }
  port_edge_nodes
}

