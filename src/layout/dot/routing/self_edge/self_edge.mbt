///|
type RankDir = @rankdir.RankDir

///|
type EdgeRouteBase = @routing.EdgeRouteBase

///|
type SelfEdgeRoute = @routing.SelfEdgeRoute

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b { a } else { b }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

///|
const PORT_SIDE_BOTTOM : Int = 1
///|
const PORT_SIDE_RIGHT : Int = 2
///|
const PORT_SIDE_TOP : Int = 4
///|
const PORT_SIDE_LEFT : Int = 8

///|
pub(all) struct SelfEdgeRightSpaceInput {
  edges : Array[@cgraph.Edge]
  sizes : Map[String, @node_primitives.NodeSize]
  rankdir : RankDir
  self_edge_size_pt : Double
  self_edge_label_width_for : (@cgraph.Edge, RankDir) -> Double
  port_side_mask_for : (@cgraph.Node, @cgraph.Port?) -> Int
}

///|
fn self_edge_right_space_for(
  edge : @cgraph.Edge,
  input : SelfEdgeRightSpaceInput,
) -> Double {
  let tail_port = edge.tail_port()
  let head_port = edge.head_port()
  let tail_explicit = @edge_identity.port_is_explicit(tail_port)
  let head_explicit = @edge_identity.port_is_explicit(head_port)
  let label_width =
    (input.self_edge_label_width_for)(edge, input.rankdir)
  if !tail_explicit && !head_explicit {
    return input.self_edge_size_pt + label_width
  }
  let tail_sides = (input.port_side_mask_for)(edge.tail(), tail_port)
  let head_sides = (input.port_side_mask_for)(edge.head(), head_port)
  let tail_left = (tail_sides & PORT_SIDE_LEFT) != 0
  let head_left = (head_sides & PORT_SIDE_LEFT) != 0
  if !tail_left && !head_left {
    let same_side = tail_sides == head_sides
    let top_bottom = (tail_sides & (PORT_SIDE_TOP | PORT_SIDE_BOTTOM)) != 0
    if !same_side || !top_bottom {
      return input.self_edge_size_pt + label_width
    }
  }
  0.0
}

///|
/// Graphviz parity: self-edge right-side spacing aligned to
/// refs/graphviz/lib/dotgen/position.c (self-edge width padding).
/// Do not change behavior without updating fixtures/tests.
pub fn apply_self_edge_right_space(
  input : SelfEdgeRightSpaceInput,
) -> Map[String, @node_primitives.NodeSize] {
  let extra_right : Map[String, Double] = Map::new()
  for edge in input.edges {
    if !@edge_semantics.edge_is_self(edge) {
      continue
    }
    let tail = edge.tail().name()
    let extra = self_edge_right_space_for(edge, input)
    if extra <= 0.0 {
      continue
    }
    let current = match extra_right.get(tail) {
      Some(value) => value
      None => 0.0
    }
    extra_right[tail] = current + extra
  }
  if extra_right.length() == 0 {
    return input.sizes
  }
  let adjusted : Map[String, @node_primitives.NodeSize] = Map::new()
  for name, size in input.sizes {
    match extra_right.get(name) {
      Some(extra) =>
        adjusted[name] =
          @node_primitives.vnode_size_from_widths_with_h(
            size.left_pt,
            size.right_pt + extra,
            size.height_pt,
          )
      None => adjusted[name] = size
    }
  }
  adjusted
}


///|
/// Graphviz parity: self-edge routing groups reuse edge_parallel_key classes.
/// Do not change behavior without updating fixtures/tests.
fn self_edge_group_key(edge : @cgraph.Edge) -> String {
  @edge_ops.edge_parallel_key(
    edge.tail().name(),
    edge.head().name(),
    edge.tail_port(),
    edge.head_port(),
  )
}

///|
/// Graphviz parity: self-edge groups share generated loop routes in one pass.
/// Do not change behavior without updating fixtures/tests.
pub fn collect_self_edge_groups(
  edges : Array[@cgraph.Edge],
) -> Map[String, Array[@cgraph.Edge]] {
  let self_edge_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    if edge.tail().name() != edge.head().name() {
      continue
    }
    let key = self_edge_group_key(edge)
    match self_edge_groups.get(key) {
      Some(list) => list.push(edge)
      None => self_edge_groups[key] = [edge]
    }
  }
  self_edge_groups
}

///|
/// Graphviz parity: self-edge route cache reuse keeps grouped self loops
/// synchronized before layout emission.
/// Do not change behavior without updating fixtures/tests.
priv struct EnsureSelfEdgeRoutesInput {
  edge : @cgraph.Edge
  self_edge_groups : Map[String, Array[@cgraph.Edge]]
  base_cache : Map[Int, EdgeRouteBase]
  nodesep_pt : Double
  rank_y : Map[Int, Double]
  self_edge_routes : Map[Int, SelfEdgeRoute]
  self_edge_label_height_fn : (@cgraph.Edge, RankDir) -> Double
  self_edge_label_width_fn : (@cgraph.Edge, RankDir) -> Double
}

///|
fn ensure_self_edge_routes(
  input : EnsureSelfEdgeRoutesInput,
) -> Unit {
  let edge = input.edge
  let self_edge_groups = input.self_edge_groups
  let base_cache = input.base_cache
  let nodesep_pt = input.nodesep_pt
  let rank_y = input.rank_y
  let self_edge_routes = input.self_edge_routes
  let self_edge_label_height_fn = input.self_edge_label_height_fn
  let self_edge_label_width_fn = input.self_edge_label_width_fn
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
        build_self_edge_routes(
          {
            edges: group_edges,
            bases: group_bases,
            nodesep_pt,
            rank_y,
            self_edge_label_height_fn,
            self_edge_label_width_fn,
          },
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
pub(all) struct SelfEdgeRouteLookupInput {
  edge : @cgraph.Edge
  self_edge_groups : Map[String, Array[@cgraph.Edge]]
  base_cache : Map[Int, EdgeRouteBase]
  nodesep_pt : Double
  rank_y : Map[Int, Double]
  self_edge_routes : Map[Int, SelfEdgeRoute]
  self_edge_label_height_fn : (@cgraph.Edge, RankDir) -> Double
  self_edge_label_width_fn : (@cgraph.Edge, RankDir) -> Double
}

///|
pub fn self_edge_route_for_edge(
  input : SelfEdgeRouteLookupInput,
) -> SelfEdgeRoute? {
  let edge = input.edge
  let self_edge_groups = input.self_edge_groups
  let base_cache = input.base_cache
  let nodesep_pt = input.nodesep_pt
  let rank_y = input.rank_y
  let self_edge_routes = input.self_edge_routes
  let self_edge_label_height_fn = input.self_edge_label_height_fn
  let self_edge_label_width_fn = input.self_edge_label_width_fn
  if edge.tail().name() != edge.head().name() {
    return None
  }
  ensure_self_edge_routes(
    {
      edge,
      self_edge_groups,
      base_cache,
      nodesep_pt,
      rank_y,
      self_edge_routes,
      self_edge_label_height_fn,
      self_edge_label_width_fn,
    },
  )
  self_edge_routes.get(edge.id())
}
