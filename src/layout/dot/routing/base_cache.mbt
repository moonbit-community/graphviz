///|
/// Graphviz parity: edge route bases are cached per edge id before routing.
/// Do not change behavior without updating fixtures/tests.
pub fn build_route_base_cache(
  edges : Array[@cgraph.Edge],
  build_base : (@cgraph.Edge) -> EdgeRouteBase,
) -> Map[Int, EdgeRouteBase] {
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  for edge in edges {
    let edge_id = edge.id()
    if base_cache.get(edge_id) is None {
      base_cache[edge_id] = build_base(edge)
    }
  }
  base_cache
}
