///|
/// Graphviz parity: self-edge route cache reuse keeps grouped self loops
/// synchronized before layout emission.
/// Do not change behavior without updating fixtures/tests.
fn ensure_self_edge_routes(
  edge : @cgraph.Edge,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  build_group_routes : (
    Array[@cgraph.Edge],
    Array[EdgeRouteBase],
    Double,
    Map[Int, Double],
  ) -> Array[SelfEdgeRoute],
) -> Unit {
  let edge_id = edge.id()
  if self_edge_routes.get(edge_id) is Some(_) {
    return ()
  }
  let key = self_edge_group_key(edge)
  match self_edge_groups.get(key) {
    Some(group_edges) => {
      let group_bases : Array[EdgeRouteBase] = []
      for grouped in group_edges {
        let gid = grouped.id()
        let gbase = match base_cache.get(gid) {
          Some(value) => value
          None => return ()
        }
        group_bases.push(gbase)
      }
      let group_routes =
        build_group_routes(
          group_edges,
          group_bases,
          nodesep_pt,
          rank_y,
        )
      for i in 0..<group_edges.length() {
        self_edge_routes[group_edges[i].id()] = group_routes[i]
      }
    }
    None => ()
  }
}

///|
/// Graphviz parity: self-edge route lookup ensures grouped route cache first.
/// Do not change behavior without updating fixtures/tests.
pub fn self_edge_route_for_edge(
  edge : @cgraph.Edge,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  build_group_routes : (
    Array[@cgraph.Edge],
    Array[EdgeRouteBase],
    Double,
    Map[Int, Double],
  ) -> Array[SelfEdgeRoute],
) -> SelfEdgeRoute? {
  if edge.tail().name() != edge.head().name() {
    return None
  }
  ensure_self_edge_routes(
    edge,
    self_edge_groups,
    base_cache,
    nodesep_pt,
    rank_y,
    self_edge_routes,
    build_group_routes,
  )
  self_edge_routes.get(edge.id())
}
