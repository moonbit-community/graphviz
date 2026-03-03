///|
/// Graphviz parity: regular-edge bezier reuse only expands from the first
/// ordered edge in each parallel vnode class.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_parallel_reuse_siblings(
  edge : @cgraph.Edge,
  raw_bezier : Array[@geom.Point],
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]],
) -> Array[@cgraph.Edge] {
  if raw_bezier.length() == 0 {
    return []
  }
  let regular_key = @dot_shared.edge_vnode_key(edge)
  let group_edges = match regular_parallel_groups.get(regular_key) {
    Some(value) => value
    None => return []
  }
  if group_edges.length() <= 1 || group_edges[0].id() != edge.id() {
    return []
  }
  let siblings : Array[@cgraph.Edge] = []
  for group_edge in group_edges {
    if group_edge.id() != edge.id() {
      siblings.push(group_edge)
    }
  }
  siblings
}
