fn cmp_edge_id(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
/// Graphviz parity: adjacent same-rank no-port/no-label multiedges use the
/// makeSimpleFlat spindle path (dotsplines.c).
/// Do not change behavior without updating fixtures/tests.
fn collect_flat_adjacent_beziers(
  edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
) -> Map[Int, Array[@geom.Point]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    if edge_is_self(edge) {
      continue
    }
    if edge_has_label(edge) {
      continue
    }
    if @dot_shared.port_is_explicit(edge.tail_port()) ||
      @dot_shared.port_is_explicit(edge.head_port()) {
      continue
    }
    if @edge_ops.edge_has_sameport_mark(edge) {
      continue
    }
    let tail_rank = match ranks.get(edge.tail().name()) {
      Some(value) => value
      None => continue
    }
    let head_rank = match ranks.get(edge.head().name()) {
      Some(value) => value
      None => continue
    }
    if tail_rank != head_rank {
      continue
    }
    let tail_order = match order_index.get(edge.tail().name()) {
      Some(value) => value
      None => continue
    }
    let head_order = match order_index.get(edge.head().name()) {
      Some(value) => value
      None => continue
    }
    let order_delta = tail_order - head_order
    if !(order_delta == 1 || order_delta == -1) {
      continue
    }
    let base = match base_cache.get(edge.id()) {
      Some(value) => value
      None => continue
    }
    if base.has_side_anchor || base.has_vnodes ||
      !base.tail_clip_enabled || !base.head_clip_enabled {
      continue
    }
    let key =
      "\{edge.tail().name()}|\{@dot_shared.port_key(edge.tail_port())}|\{edge.head().name()}|\{@dot_shared.port_key(edge.head_port())}"
    match groups.get(key) {
      Some(list) => list.push(edge)
      None => groups[key] = [edge]
    }
  }
  let out : Map[Int, Array[@geom.Point]] = Map::new()
  for _key, group_edges in groups {
    if group_edges.length() <= 1 {
      continue
    }
    let rep = match base_cache.get(group_edges[0].id()) {
      Some(value) => value
      None => continue
    }
    let tx = rep.tail_anchor.x
    let ty = rep.tail_anchor.y
    let hx = rep.head_anchor.x
    let hy = rep.head_anchor.y
    let vx = hx - tx
    let vy = hy - ty
    let vlen = Double::sqrt(vx * vx + vy * vy)
    if vlen <= 0.0 {
      continue
    }
    let dir_x = vx / vlen
    let dir_y = vy / vlen
    let perp_x = -dir_y
    let perp_y = dir_x
    let base_span =
      if Double::abs(perp_x) >= Double::abs(perp_y) {
        rep.tail_size.width_pt
      } else {
        rep.tail_size.height_pt
      }
    let span = base_span
    if span <= 0.0 {
      continue
    }
    group_edges.sort_by((a, b) => cmp_edge_id(a.id(), b.id()))
    let count = group_edges.length()
    let base_one_third = @edge_spline.point(
      tx + (hx - tx) / 3.0,
      ty + (hy - ty) / 3.0,
    )
    let base_two_third = @edge_spline.point(
      tx + (hx - tx) * 2.0 / 3.0,
      ty + (hy - ty) * 2.0 / 3.0,
    )
    let denom =
      if count > 1 { Double::from_int(count - 1) } else { 1.0 }
    for i in 0..<count {
      let frac = Double::from_int(i) / denom
      let offset = -span / 2.0 + span * frac
      let shift = @edge_spline.point(perp_x * offset, perp_y * offset)
      let edge = group_edges[i]
      let edge_base = match base_cache.get(edge.id()) {
        Some(value) => value
        None => continue
      }
      let c1 = @edge_spline.point_add(base_one_third, shift)
      let c2 = @edge_spline.point_add(base_two_third, shift)
      out[edge.id()] = [
        edge_base.tail_anchor,
        c1,
        c2,
        edge_base.head_anchor,
      ]
    }
  }
  out
}

///|
pub(all) struct RoutePrepassState {
  flat_adjacent_simple_beziers : Map[Int, Array[@geom.Point]]
  ordered_edges : Array[@cgraph.Edge]
  recover_edge_id_for_routing : Map[String, Int]
  regular_parallel_groups : Map[String, Array[@cgraph.Edge]]
  path_left_bound : Double
  path_right_bound : Double
}

///|
/// Graphviz parity: routing prepass input keeps order maps, pathplan geometry,
/// and edge-base snapshots grouped before the ordered-routing loop.
pub(all) struct RoutePrepassInput {
  edges : Array[@cgraph.Edge]
  base_cache : Map[Int, EdgeRouteBase]
  build_flat_adjacent_beziers : Bool
  ranks : Map[String, Int]
  order_index : Map[String, Int]
  path_order_index : Map[String, Int]
  positions : Map[String, @geom.Point]
  vnode_positions : Map[String, @geom.Point]
  sizes : Map[String, @dot_shared.NodeSize]
  vnode_sizes : Map[String, @dot_shared.NodeSize]
  x_groups : Map[Int, Array[String]]
}

///|
/// Graphviz parity: routing prepass order/group/bounds setup runs before the
/// edge routing loop and follows dot/pathplan sequencing.
/// Do not change behavior without updating fixtures/tests.
pub fn build_route_prepass_state(
  input : RoutePrepassInput,
) -> RoutePrepassState {
  let flat_adjacent_simple_beziers =
    if input.build_flat_adjacent_beziers {
      collect_flat_adjacent_beziers(
        input.edges,
        input.base_cache,
        input.ranks,
        input.order_index,
      )
    } else {
      Map::new()
    }
  let path_bounds = @routesplines.pathplan_bounds(
    input.positions,
    input.vnode_positions,
    input.sizes,
    input.vnode_sizes,
    input.x_groups,
  )
  let ordered_edges =
    sorted_edges_for_routing(input.edges, input.base_cache, input.path_order_index)
  let regular_recover_plan =
    build_regular_recover_routing_plan(ordered_edges, input.base_cache)
  {
    flat_adjacent_simple_beziers,
    ordered_edges,
    recover_edge_id_for_routing: regular_recover_plan.recover_edge_id_for_routing,
    regular_parallel_groups: regular_recover_plan.regular_parallel_groups,
    path_left_bound: path_bounds.left,
    path_right_bound: path_bounds.right,
  }
}
