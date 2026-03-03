///|
pub struct RoutePrepassState {
  flat_adjacent_simple_beziers : Map[Int, Array[@geom.Point]]
  ordered_edges : Array[@cgraph.Edge]
  recover_edge_id_for_routing : Map[String, Int]
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  path_left_bound : Double
  path_right_bound : Double
}

///|
/// Graphviz parity: routing prepass order/group/bounds setup runs before the
/// edge routing loop and follows dot/pathplan sequencing.
/// Do not change behavior without updating fixtures/tests.
pub fn build_route_prepass_state(
  edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
  build_flat_adjacent_beziers : Bool,
  ranks : Map[String, Int],
  order_index : Map[String, Int],
  path_order_index : Map[String, Int],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  sizes : Map[String, @dot_shared.NodeSize],
  vnode_sizes : Map[String, @dot_shared.NodeSize],
  x_groups : Map[Int, Array[String]],
) -> RoutePrepassState {
  let flat_adjacent_simple_beziers =
    if build_flat_adjacent_beziers {
      collect_flat_adjacent_beziers(
        edges,
        base_cache,
        ranks,
        order_index,
      )
    } else {
      Map::new()
    }
  let path_bounds = @routesplines.pathplan_bounds(
    positions,
    vnode_positions,
    sizes,
    vnode_sizes,
    x_groups,
  )
  let ordered_edges =
    sorted_edges_for_routing(edges, base_cache, path_order_index)
  let regular_recover_plan =
    build_regular_recover_routing_plan(ordered_edges, base_cache)
  {
    flat_adjacent_simple_beziers,
    ordered_edges,
    recover_edge_id_for_routing: regular_recover_plan.recover_edge_id_for_routing,
    regular_parallel_groups: regular_recover_plan.regular_parallel_groups,
    path_left_bound: path_bounds.left,
    path_right_bound: path_bounds.right,
  }
}
