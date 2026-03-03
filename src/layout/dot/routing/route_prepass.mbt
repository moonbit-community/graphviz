///|
const ROUTE_EDGE_REGULAR : Int = 1
///|
const ROUTE_EDGE_FLAT : Int = 2
///|
const ROUTE_EDGE_SELF_PORT : Int = 4
///|
const ROUTE_EDGE_SELF_NOPORT : Int = 8
///|
const ROUTE_GRAPH_MAIN : Int = 64
///|
const ROUTE_GRAPH_AUX : Int = 128

///|
fn edge_route_type(base : EdgeRouteBase) -> Int {
  if base.orig_tail_name == base.orig_head_name {
    if @dot_shared.port_is_explicit(base.tail_port) ||
      @dot_shared.port_is_explicit(base.head_port) {
      ROUTE_EDGE_SELF_PORT
    } else {
      ROUTE_EDGE_SELF_NOPORT
    }
  } else if base.is_flat_edge {
    ROUTE_EDGE_FLAT
  } else {
    ROUTE_EDGE_REGULAR
  }
}

///|
fn edge_route_graph_type(edge_type : Int) -> Int {
  if edge_type == ROUTE_EDGE_REGULAR {
    ROUTE_GRAPH_MAIN
  } else {
    ROUTE_GRAPH_AUX
  }
}

///|
fn cmp_int(a : Int, b : Int) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn cmp_double(a : Double, b : Double) -> Int {
  if a < b {
    -1
  } else if a > b {
    1
  } else {
    0
  }
}

///|
fn edge_attr_or_empty(edge : @cgraph.Edge, name : String) -> String {
  match edge.get_attr(name) {
    Some(value) => value
    None => ""
  }
}

///|
fn port_cmp(
  a_defined : Bool,
  a_pos : @geom.Point,
  b_defined : Bool,
  b_pos : @geom.Point,
) -> Int {
  if !b_defined {
    if a_defined { 1 } else { 0 }
  } else if !a_defined {
    -1
  } else if a_pos.x < b_pos.x {
    -1
  } else if a_pos.x > b_pos.x {
    1
  } else if a_pos.y < b_pos.y {
    -1
  } else if a_pos.y > b_pos.y {
    1
  } else {
    0
  }
}

///|
priv struct EdgePortCmpInfo {
  tail_defined : Bool
  tail_pos : @geom.Point
  head_defined : Bool
  head_pos : @geom.Point
}

///|
fn edge_port_cmp_info(
  base : EdgeRouteBase,
  edge_type : Int,
  order_index : Map[String, Int],
) -> EdgePortCmpInfo {
  let tail_anchor =
    if base.swap_ends { base.head_anchor } else { base.tail_anchor }
  let head_anchor =
    if base.swap_ends { base.tail_anchor } else { base.head_anchor }
  let tail_pos = if base.swap_ends { base.head_pos } else { base.tail_pos }
  let head_pos = if base.swap_ends { base.tail_pos } else { base.head_pos }
  let tail_defined =
    if base.swap_ends { @dot_shared.port_is_explicit(base.head_port) } else {
      @dot_shared.port_is_explicit(base.tail_port)
    }
  let head_defined =
    if base.swap_ends { @dot_shared.port_is_explicit(base.tail_port) } else {
      @dot_shared.port_is_explicit(base.head_port)
    }
  let tail_rel =
    @edge_spline.point(tail_anchor.x - tail_pos.x, tail_anchor.y - tail_pos.y)
  let head_rel =
    @edge_spline.point(head_anchor.x - head_pos.x, head_anchor.y - head_pos.y)
  if edge_type == ROUTE_EDGE_FLAT {
    let tail_order = order_index.get(base.orig_tail_name).unwrap_or_default()
    let head_order = order_index.get(base.orig_head_name).unwrap_or_default()
    if tail_order > head_order {
      return {
        tail_defined: head_defined,
        tail_pos: head_rel,
        head_defined: tail_defined,
        head_pos: tail_rel,
      }
    }
  }
  {
    tail_defined,
    tail_pos: tail_rel,
    head_defined,
    head_pos: head_rel,
  }
}

///|
/// Graphviz parity: routing edge order matches dotgen/dotsplines.c edgecmp.
/// Do not change behavior without updating fixtures/tests.
fn route_edge_cmp(
  a : @cgraph.Edge,
  b : @cgraph.Edge,
  base_cache : Map[Int, EdgeRouteBase],
  order_index : Map[String, Int],
) -> Int {
  let base_a = match base_cache.get(a.id()) {
    Some(value) => value
    None => return 0
  }
  let base_b = match base_cache.get(b.id()) {
    Some(value) => value
    None => return 0
  }
  let type_a = edge_route_type(base_a)
  let type_b = edge_route_type(base_b)
  if type_a != type_b {
    return if type_a > type_b { -1 } else { 1 }
  }
  let rank_diff_a =
    if base_a.tail_rank >= base_a.head_rank {
      base_a.tail_rank - base_a.head_rank
    } else {
      base_a.head_rank - base_a.tail_rank
    }
  let rank_diff_b =
    if base_b.tail_rank >= base_b.head_rank {
      base_b.tail_rank - base_b.head_rank
    } else {
      base_b.head_rank - base_b.tail_rank
    }
  let rank_cmp = cmp_int(rank_diff_a, rank_diff_b)
  if rank_cmp != 0 {
    return rank_cmp
  }
  let xdiff_a = Double::abs(base_a.tail_pos.x - base_a.head_pos.x)
  let xdiff_b = Double::abs(base_b.tail_pos.x - base_b.head_pos.x)
  let xcmp = cmp_double(xdiff_a, xdiff_b)
  if xcmp != 0 {
    return xcmp
  }
  let id_a = a.id()
  let id_b = b.id()
  let id_cmp = cmp_int(id_a, id_b)
  if id_cmp != 0 {
    return id_cmp
  }
  let port_info_a = edge_port_cmp_info(base_a, type_a, order_index)
  let port_info_b = edge_port_cmp_info(base_b, type_b, order_index)
  let tail_cmp =
    port_cmp(
      port_info_a.tail_defined,
      port_info_a.tail_pos,
      port_info_b.tail_defined,
      port_info_b.tail_pos,
    )
  if tail_cmp != 0 {
    return tail_cmp
  }
  let head_cmp =
    port_cmp(
      port_info_a.head_defined,
      port_info_a.head_pos,
      port_info_b.head_defined,
      port_info_b.head_pos,
    )
  if head_cmp != 0 {
    return head_cmp
  }
  let graph_cmp = cmp_int(
    edge_route_graph_type(type_a),
    edge_route_graph_type(type_b),
  )
  if graph_cmp != 0 {
    return graph_cmp
  }
  if type_a == ROUTE_EDGE_FLAT {
    let label_a = edge_attr_or_empty(a, "label")
    let label_b = edge_attr_or_empty(b, "label")
    if label_a < label_b {
      return -1
    }
    if label_a > label_b {
      return 1
    }
  }
  cmp_int(id_a, id_b)
}

///|
/// Graphviz parity: edge routing pass order follows dot edgecmp.
/// Do not change behavior without updating fixtures/tests.
fn sorted_edges_for_routing(
  edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
  order_index : Map[String, Int],
) -> Array[@cgraph.Edge] {
  let ordered_edges = edges.copy()
  if ordered_edges.length() > 1 {
    ordered_edges.sort_by((a, b) => {
      route_edge_cmp(a, b, base_cache, order_index)
    })
  }
  ordered_edges
}

///|
fn flat_adjacent_edge_is_self(edge : @cgraph.Edge) -> Bool {
  edge.tail().name() == edge.head().name()
}

///|
fn flat_adjacent_edge_has_label(edge : @cgraph.Edge) -> Bool {
  match edge.get_attr("label") {
    Some(value) => value != ""
    None => false
  }
}

///|
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
    if flat_adjacent_edge_is_self(edge) {
      continue
    }
    if flat_adjacent_edge_has_label(edge) {
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
pub struct RoutePrepassState {
  flat_adjacent_simple_beziers : Map[Int, Array[@geom.Point]]
  ordered_edges : Array[@cgraph.Edge]
  self_edge_groups : Map[String, Array[@cgraph.Edge]]
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
  let self_edge_groups = collect_self_edge_groups(edges)
  let regular_recover_plan =
    build_regular_recover_routing_plan(ordered_edges, base_cache)
  {
    flat_adjacent_simple_beziers,
    ordered_edges,
    self_edge_groups,
    recover_edge_id_for_routing: regular_recover_plan.recover_edge_id_for_routing,
    regular_parallel_groups: regular_recover_plan.regular_parallel_groups,
    path_left_bound: path_bounds.left,
    path_right_bound: path_bounds.right,
  }
}
