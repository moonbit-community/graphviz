///|
/// Graphviz parity: self-edge route cache reuse + self-edge layout finalize path.
/// Do not change behavior without updating fixtures/tests.
fn maybe_build_self_edge_layout(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  build_base : (@cgraph.Edge) -> EdgeRouteBase,
  ranks : Map[String, Int],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Bool {
  let edge_id = edge.id()
  let route = @routing.self_edge_route_for_edge(
    edge,
    self_edge_groups,
    base_cache,
    nodesep_pt,
    rank_y,
    self_edge_routes,
    build_base,
    build_self_edge_routes,
  )
  match route {
    Some(route) => {
      let edge_layout =
        build_self_edge_layout(
          base,
          route,
          ranks,
          rank_y,
          vnode_info,
          vnode_positions,
          nodesep_pt,
          has_clusters,
          flat_label_edge_vnodes,
        )
      edges_out_by_id[edge_id] = edge_layout
      true
    }
    None => false
  }
}
