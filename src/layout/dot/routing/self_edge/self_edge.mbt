///|
type RankDir = @dot_shared.RankDir

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
  sizes : Map[String, @dot_shared.NodeSize]
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
  let tail_explicit = @dot_shared.port_is_explicit(tail_port)
  let head_explicit = @dot_shared.port_is_explicit(head_port)
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
) -> Map[String, @dot_shared.NodeSize] {
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
  let adjusted : Map[String, @dot_shared.NodeSize] = Map::new()
  for name, size in input.sizes {
    match extra_right.get(name) {
      Some(extra) =>
        adjusted[name] =
          @dot_shared.vnode_size_from_widths_with_h(
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
priv struct RankBounds {
  min_rank : Int
  max_rank : Int
}

///|
fn rank_bounds(rank_y : Map[Int, Double]) -> RankBounds {
  let mut min_rank = 0
  let mut max_rank = 0
  let mut seen = false
  for rank, _ in rank_y {
    if !seen {
      min_rank = rank
      max_rank = rank
      seen = true
    } else {
      if rank < min_rank { min_rank = rank }
      if rank > max_rank { max_rank = rank }
    }
  }
  { min_rank, max_rank }
}

///|
priv struct SelfEdgeRankSpacingInput {
  rank : Int
  rank_y : Map[Int, Double]
  node_y : Double
  node_height : Double
  min_rank : Int
  max_rank : Int
}

///|
fn self_edge_rank_spacing(
  input : SelfEdgeRankSpacingInput,
) -> Double {
  let rank = input.rank
  let rank_y = input.rank_y
  let node_y = input.node_y
  let node_height = input.node_height
  let min_rank = input.min_rank
  let max_rank = input.max_rank
  if min_rank == max_rank {
    return node_height
  }
  if rank == max_rank {
    if rank > min_rank {
      match rank_y.get(rank - 1) {
        Some(prev) => Double::abs(prev - node_y)
        None => node_height
      }
    } else {
      node_height
    }
  } else if rank == min_rank {
    match rank_y.get(rank + 1) {
      Some(next) => Double::abs(node_y - next)
      None => node_height
    }
  } else {
    let up = match rank_y.get(rank - 1) {
      Some(prev) => Double::abs(prev - node_y)
      None => node_height
    }
    let down = match rank_y.get(rank + 1) {
      Some(next) => Double::abs(node_y - next)
      None => node_height
    }
    min_double(up, down)
  }
}

///|
fn convert_sides_to_points(tail_side : Int, head_side : Int) -> Int {
  let vertices : Array[Int] = [12, 4, 6, 2, 3, 1, 9, 8]
  let pair_a : Array[Array[Int]] = [
    [11, 12, 13, 14, 15, 16, 17, 18],
    [21, 22, 23, 24, 25, 26, 27, 28],
    [31, 32, 33, 34, 35, 36, 37, 38],
    [41, 42, 43, 44, 45, 46, 47, 48],
    [51, 52, 53, 54, 55, 56, 57, 58],
    [61, 62, 63, 64, 65, 66, 67, 68],
    [71, 72, 73, 74, 75, 76, 77, 78],
    [81, 82, 83, 84, 85, 86, 87, 88],
  ]
  let mut tail_i = -1
  let mut head_i = -1
  for i in 0..<vertices.length() {
    if tail_side == vertices[i] {
      tail_i = i
      break
    }
  }
  for i in 0..<vertices.length() {
    if head_side == vertices[i] {
      head_i = i
      break
    }
  }
  if tail_i < 0 || head_i < 0 {
    0
  } else {
    pair_a[tail_i][head_i]
  }
}

///|
priv struct TopSelfEdgeRoutesInput {
  edges : Array[@cgraph.Edge]
  base0 : EdgeRouteBase
  nodesep_pt : Double
  sizey_param : Double
  point_pair : Int
  self_edge_label_height_fn : (@cgraph.Edge, RankDir) -> Double
}

///|
fn self_edge_routes_top(
  input : TopSelfEdgeRoutesInput,
) -> Array[SelfEdgeRoute] {
  let edges = input.edges
  let base0 = input.base0
  let nodesep_pt = input.nodesep_pt
  let sizey_param = input.sizey_param
  let point_pair = input.point_pair
  let self_edge_label_height_fn = input.self_edge_label_height_fn
  let cnt = edges.length()
  let cnt_f = Double::from_int(cnt)
  let stepx = max_double(nodesep_pt / 2.0 / cnt_f, 2.0)
  let stepy = sizey_param
  let np = base0.tail_pos
  let tp = base0.tail_anchor
  let hp = base0.head_anchor
  let sgn = if tp.x >= hp.x { 1.0 } else { -1.0 }
  let lw = base0.tail_size.left_pt
  let rw = base0.tail_size.right_pt
  let mut dx = 0.0
  match point_pair {
    15 => {
      dx = sgn * (rw - (hp.x - np.x) + stepx)
    }
    38 => {
      dx = sgn * (lw - (np.x - hp.x) + stepx)
    }
    41 | 48 => {
      dx = sgn * (rw - (tp.x - np.x) + stepx)
    }
    14 | 37 | 47 | 51 | 57 | 58 => {
      dx =
        sgn *
          ((lw - (np.x - tp.x) + (rw - (hp.x - np.x))) / 3.0)
    }
    73 => {
      dx = sgn * (lw - (np.x - tp.x) + stepx)
    }
    83 => {
      dx = sgn * (lw - (np.x - tp.x))
    }
    84 => {
      dx =
        sgn *
          ((lw - (np.x - tp.x) + (rw - (hp.x - np.x))) / 2.0 + stepx)
    }
    74 | 75 | 85 => {
      dx =
        sgn *
          ((lw - (np.x - tp.x) + (rw - (hp.x - np.x))) / 2.0 + 2.0 * stepx)
    }
    _ => ()
  }
  let mut dy = base0.tail_size.height_pt / 2.0
  let mut ty = min_double(dy, 3.0 * (np.y + dy - tp.y))
  let mut hy = min_double(dy, 3.0 * (np.y + dy - hp.y))
  let routes : Array[SelfEdgeRoute] = []
  for i in 0..<cnt {
    let edge = edges[i]
    dy = dy + stepy
    ty = ty + stepy
    hy = hy + stepy
    dx = dx + sgn * stepx
    let points = [
      tp,
      @edge_spline.point(tp.x + dx, tp.y + ty / 3.0),
      @edge_spline.point(tp.x + dx, np.y + dy),
      @edge_spline.point((tp.x + hp.x) / 2.0, np.y + dy),
      @edge_spline.point(hp.x - dx, np.y + dy),
      @edge_spline.point(hp.x - dx, hp.y + hy / 3.0),
      hp,
    ]
    let mut label_pos : @geom.Point? = None
    let label_height =
      self_edge_label_height_fn(edge, base0.layout_rankdir)
    if label_height > 0.0 {
      label_pos = Some(@edge_spline.point(np.x, np.y + dy + label_height / 2.0))
      if label_height > stepy {
        dy = dy + (label_height - stepy)
      }
    }
    routes.push({ points, label_pos })
  }
  routes
}

///|
priv struct BottomSelfEdgeRoutesInput {
  edges : Array[@cgraph.Edge]
  base0 : EdgeRouteBase
  nodesep_pt : Double
  sizey_param : Double
  point_pair : Int
  self_edge_label_height_fn : (@cgraph.Edge, RankDir) -> Double
}

///|
fn self_edge_routes_bottom(
  input : BottomSelfEdgeRoutesInput,
) -> Array[SelfEdgeRoute] {
  let edges = input.edges
  let base0 = input.base0
  let nodesep_pt = input.nodesep_pt
  let sizey_param = input.sizey_param
  let point_pair = input.point_pair
  let self_edge_label_height_fn = input.self_edge_label_height_fn
  let cnt = edges.length()
  let cnt_f = Double::from_int(cnt)
  let stepx = max_double(nodesep_pt / 2.0 / cnt_f, 2.0)
  let stepy = sizey_param
  let np = base0.tail_pos
  let tp = base0.tail_anchor
  let hp = base0.head_anchor
  let mut sgn = if tp.x >= hp.x { 1.0 } else { -1.0 }
  if point_pair == 67 {
    sgn = -sgn
  }
  let mut dx = 0.0
  let mut dy = base0.tail_size.height_pt / 2.0
  let mut ty = min_double(dy, 3.0 * (tp.y + dy - np.y))
  let mut hy = min_double(dy, 3.0 * (hp.y + dy - np.y))
  let routes : Array[SelfEdgeRoute] = []
  for i in 0..<cnt {
    let edge = edges[i]
    dy = dy + stepy
    ty = ty + stepy
    hy = hy + stepy
    dx = dx + sgn * stepx
    let points = [
      tp,
      @edge_spline.point(tp.x + dx, tp.y - ty / 3.0),
      @edge_spline.point(tp.x + dx, np.y - dy),
      @edge_spline.point((tp.x + hp.x) / 2.0, np.y - dy),
      @edge_spline.point(hp.x - dx, np.y - dy),
      @edge_spline.point(hp.x - dx, hp.y - hy / 3.0),
      hp,
    ]
    let mut label_pos : @geom.Point? = None
    let label_height =
      self_edge_label_height_fn(edge, base0.layout_rankdir)
    if label_height > 0.0 {
      label_pos = Some(@edge_spline.point(np.x, np.y - dy - label_height / 2.0))
      if label_height > stepy {
        dy = dy + (label_height - stepy)
      }
    }
    routes.push({ points, label_pos })
  }
  routes
}

///|
fn resolve_self_edge_port_side(
  port_side : Int,
  port : @cgraph.Port?,
  all_sides : Int,
) -> Int {
  if port_side != 0 {
    return port_side
  }
  match port {
    Some(value) =>
      if value.compass is None {
        // Graphviz parity: side-less label ports on self-edges still behave
        // like fully-open sides when dynamic side resolution is unavailable.
        all_sides
      } else {
        0
      }
    None => 0
  }
}

///|
/// Graphviz parity: left/right horizontal self-edge route shapes share one
/// control-point construction, with only side-specific sign/seed differences.
/// Do not change behavior without updating fixtures/tests.
priv struct HorizontalSelfEdgeRoutesInput {
  edges : Array[@cgraph.Edge]
  base0 : EdgeRouteBase
  nodesep_pt : Double
  sizey_param : Double
  np : @geom.Point
  tp : @geom.Point
  hp : @geom.Point
  point_pair : Int
  flip_pair_a : Int
  flip_pair_b : Int
  side_width : Double
  to_right : Bool
  self_edge_label_width_fn : (@cgraph.Edge, RankDir) -> Double
}

///|
fn self_edge_routes_horizontal_side(
  input : HorizontalSelfEdgeRoutesInput,
) -> Array[SelfEdgeRoute] {
  let edges = input.edges
  let base0 = input.base0
  let nodesep_pt = input.nodesep_pt
  let sizey_param = input.sizey_param
  let np = input.np
  let tp = input.tp
  let hp = input.hp
  let point_pair = input.point_pair
  let flip_pair_a = input.flip_pair_a
  let flip_pair_b = input.flip_pair_b
  let side_width = input.side_width
  let to_right = input.to_right
  let self_edge_label_width_fn = input.self_edge_label_width_fn
  let cnt = edges.length()
  let cnt_f = Double::from_int(cnt)
  let stepx = nodesep_pt
  let stepy = max_double(sizey_param / 2.0 / cnt_f, 2.0)
  let mut sgn = if tp.y >= hp.y { 1.0 } else { -1.0 }
  if (point_pair == flip_pair_a || point_pair == flip_pair_b) && tp.y == hp.y {
    sgn = -sgn
  }
  let mut dx = side_width
  let mut dy = 0.0
  let mut tx =
    if to_right {
      min_double(dx, 3.0 * (np.x + dx - tp.x))
    } else {
      min_double(dx, 3.0 * (tp.x + dx - np.x))
    }
  let mut hx =
    if to_right {
      min_double(dx, 3.0 * (np.x + dx - hp.x))
    } else {
      min_double(dx, 3.0 * (hp.x + dx - np.x))
    }
  let x_sign = if to_right { 1.0 } else { -1.0 }
  let routes : Array[SelfEdgeRoute] = []
  for i in 0..<cnt {
    let edge = edges[i]
    dx = dx + stepx
    tx = tx + stepx
    hx = hx + stepx
    dy = dy + sgn * stepy
    let points = [
      tp,
      @edge_spline.point(tp.x + x_sign * tx / 3.0, tp.y + dy),
      @edge_spline.point(np.x + x_sign * dx, tp.y + dy),
      @edge_spline.point(np.x + x_sign * dx, (tp.y + hp.y) / 2.0),
      @edge_spline.point(np.x + x_sign * dx, hp.y - dy),
      @edge_spline.point(hp.x + x_sign * hx / 3.0, hp.y - dy),
      hp,
    ]
    let mut label_pos : @geom.Point? = None
    let label_width =
      self_edge_label_width_fn(edge, base0.rankdir)
    if label_width > 0.0 {
      label_pos = Some(
        @edge_spline.point(np.x + x_sign * (dx + label_width / 2.0), np.y),
      )
      if label_width > stepx {
        dx = dx + (label_width - stepx)
      }
    }
    routes.push({ points, label_pos })
  }
  routes
}

///|
/// Graphviz parity: self-edge routing aligned to refs/graphviz/lib/common/splines.c.
/// Do not change behavior without updating fixtures/tests.
priv struct BuildSelfEdgeRoutesInput {
  edges : Array[@cgraph.Edge]
  bases : Array[EdgeRouteBase]
  nodesep_pt : Double
  rank_y : Map[Int, Double]
  self_edge_label_height_fn : (@cgraph.Edge, RankDir) -> Double
  self_edge_label_width_fn : (@cgraph.Edge, RankDir) -> Double
}

///|
fn build_self_edge_routes(
  input : BuildSelfEdgeRoutesInput,
) -> Array[SelfEdgeRoute] {
  let edges = input.edges
  let bases = input.bases
  let nodesep_pt = input.nodesep_pt
  let rank_y = input.rank_y
  let self_edge_label_height_fn = input.self_edge_label_height_fn
  let self_edge_label_width_fn = input.self_edge_label_width_fn
  if edges.length() == 0 {
    return []
  }
  let base0 = bases[0]
  let np = base0.tail_pos
  let tp = base0.tail_anchor
  let hp = base0.head_anchor
  let all_sides =
    PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT | PORT_SIDE_TOP | PORT_SIDE_LEFT
  let tail_side =
    resolve_self_edge_port_side(
      base0.tail_port_side,
      base0.tail_port,
      all_sides,
    )
  let head_side =
    resolve_self_edge_port_side(
      base0.head_port_side,
      base0.head_port,
      all_sides,
    )
  let tail_defined = @dot_shared.port_is_explicit(base0.tail_port)
  let head_defined = @dot_shared.port_is_explicit(base0.head_port)
  let bounds = rank_bounds(rank_y)
  let sizey =
    self_edge_rank_spacing(
      {
        rank: base0.tail_rank,
        rank_y,
        node_y: np.y,
        node_height: base0.tail_size.height_pt,
        min_rank: bounds.min_rank,
        max_rank: bounds.max_rank,
      },
    )
  let sizey_param = sizey / 2.0
  let same_side = tail_side == head_side
  let tail_tb = (tail_side & (PORT_SIDE_TOP | PORT_SIDE_BOTTOM)) != 0
  let go_right =
    (!tail_defined && !head_defined) ||
      (
        (tail_side & PORT_SIDE_LEFT) == 0 &&
          (head_side & PORT_SIDE_LEFT) == 0 &&
          (!same_side || !tail_tb)
      )
  let uses_left =
    (tail_side & PORT_SIDE_LEFT) != 0 || (head_side & PORT_SIDE_LEFT) != 0
  let uses_right =
    (tail_side & PORT_SIDE_RIGHT) != 0 || (head_side & PORT_SIDE_RIGHT) != 0
  if go_right {
    let point_pair = convert_sides_to_points(tail_side, head_side)
    return self_edge_routes_horizontal_side(
      {
        edges,
        base0,
        nodesep_pt,
        sizey_param,
        np,
        tp,
        hp,
        point_pair,
        flip_pair_a: 32,
        flip_pair_b: 65,
        side_width: base0.tail_size.right_pt,
        to_right: true,
        self_edge_label_width_fn,
      },
    )
  }
  if uses_left {
    if uses_right {
      return self_edge_routes_top(
        {
          edges,
          base0,
          nodesep_pt,
          sizey_param,
          point_pair: convert_sides_to_points(tail_side, head_side),
          self_edge_label_height_fn,
        },
      )
    } else {
      let point_pair = convert_sides_to_points(tail_side, head_side)
      return self_edge_routes_horizontal_side(
        {
          edges,
          base0,
          nodesep_pt,
          sizey_param,
          np,
          tp,
          hp,
          point_pair,
          flip_pair_a: 12,
          flip_pair_b: 67,
          side_width: base0.tail_size.left_pt,
          to_right: false,
          self_edge_label_width_fn,
        },
      )
    }
  }
  let point_pair = convert_sides_to_points(tail_side, head_side)
  if (tail_side & PORT_SIDE_TOP) != 0 {
    return self_edge_routes_top(
      {
        edges,
        base0,
        nodesep_pt,
        sizey_param,
        point_pair,
        self_edge_label_height_fn,
      },
    )
  }
  if (tail_side & PORT_SIDE_BOTTOM) != 0 {
    return self_edge_routes_bottom(
      {
        edges,
        base0,
        nodesep_pt,
        sizey_param,
        point_pair,
        self_edge_label_height_fn,
      },
    )
  }
  self_edge_routes_top(
    {
      edges,
      base0,
      nodesep_pt,
      sizey_param,
      point_pair,
      self_edge_label_height_fn,
    },
  )
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
