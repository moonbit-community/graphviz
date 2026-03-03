///|
fn self_edge_label_height_pt(edge : @cgraph.Edge, rankdir : RankDir) -> Double {
  match edge_mid_label_metrics(edge) {
    Some(metrics) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        metrics.width
      } else {
        metrics.height
      }
    None => 0.0
  }
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
fn self_edge_rank_spacing(
  rank : Int,
  rank_y : Map[Int, Double],
  node_y : Double,
  node_height : Double,
  min_rank : Int,
  max_rank : Int,
) -> Double {
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
fn self_edge_routes_top(
  edges : Array[@cgraph.Edge],
  base0 : @routing.EdgeRouteBase,
  nodesep_pt : Double,
  sizey_param : Double,
  point_pair : Int,
) -> Array[@routing.SelfEdgeRoute] {
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
  let routes : Array[@routing.SelfEdgeRoute] = []
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
    let label_height = self_edge_label_height_pt(edge, base0.layout_rankdir)
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
fn self_edge_routes_bottom(
  edges : Array[@cgraph.Edge],
  base0 : @routing.EdgeRouteBase,
  nodesep_pt : Double,
  sizey_param : Double,
  point_pair : Int,
) -> Array[@routing.SelfEdgeRoute] {
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
  let routes : Array[@routing.SelfEdgeRoute] = []
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
    let label_height = self_edge_label_height_pt(edge, base0.layout_rankdir)
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
/// Graphviz parity: self-edge routing aligned to refs/graphviz/lib/common/splines.c.
/// Do not change behavior without updating fixtures/tests.
fn build_self_edge_routes(
  edges : Array[@cgraph.Edge],
  bases : Array[@routing.EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
) -> Array[@routing.SelfEdgeRoute] {
  if edges.length() == 0 {
    return []
  }
  let base0 = bases[0]
  let np = base0.tail_pos
  let tp = base0.tail_anchor
  let hp = base0.head_anchor
  let all_sides =
    PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT | PORT_SIDE_TOP | PORT_SIDE_LEFT
  let tail_side = if base0.tail_port_side == 0 {
    match base0.tail_port {
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
  } else {
    base0.tail_port_side
  }
  let head_side = if base0.head_port_side == 0 {
    match base0.head_port {
      Some(value) =>
        if value.compass is None {
          all_sides
        } else {
          0
        }
      None => 0
    }
  } else {
    base0.head_port_side
  }
  let tail_defined = @dot_shared.port_is_explicit(base0.tail_port)
  let head_defined = @dot_shared.port_is_explicit(base0.head_port)
  let bounds = rank_bounds(rank_y)
  let sizey =
    self_edge_rank_spacing(
      base0.tail_rank,
      rank_y,
      np.y,
      base0.tail_size.height_pt,
      bounds.min_rank,
      bounds.max_rank,
    )
  let sizey_param = sizey / 2.0
  let cnt = edges.length()
  let cnt_f = Double::from_int(cnt)
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
    let stepx = nodesep_pt
    let stepy = max_double(sizey_param / 2.0 / cnt_f, 2.0)
    let mut sgn = if tp.y >= hp.y { 1.0 } else { -1.0 }
    let point_pair = convert_sides_to_points(tail_side, head_side)
    if (point_pair == 32 || point_pair == 65) && tp.y == hp.y {
      sgn = -sgn
    }
    let mut dx = base0.tail_size.right_pt
    let mut dy = 0.0
    let mut tx = min_double(dx, 3.0 * (np.x + dx - tp.x))
    let mut hx = min_double(dx, 3.0 * (np.x + dx - hp.x))
    let routes : Array[@routing.SelfEdgeRoute] = []
    for i in 0..<cnt {
      let edge = edges[i]
      dx = dx + stepx
      tx = tx + stepx
      hx = hx + stepx
      dy = dy + sgn * stepy
      let points = [
        tp,
        @edge_spline.point(tp.x + tx / 3.0, tp.y + dy),
        @edge_spline.point(np.x + dx, tp.y + dy),
        @edge_spline.point(np.x + dx, (tp.y + hp.y) / 2.0),
        @edge_spline.point(np.x + dx, hp.y - dy),
        @edge_spline.point(hp.x + hx / 3.0, hp.y - dy),
        hp,
      ]
      let mut label_pos : @geom.Point? = None
      let label_width = self_edge_label_width_pt(edge, base0.rankdir)
      if label_width > 0.0 {
        label_pos = Some(@edge_spline.point(np.x + dx + label_width / 2.0, np.y))
        if label_width > stepx {
          dx = dx + (label_width - stepx)
        }
      }
      routes.push({ points, label_pos })
    }
    return routes
  }
  if uses_left {
    if uses_right {
      return self_edge_routes_top(
        edges,
        base0,
        nodesep_pt,
        sizey_param,
        convert_sides_to_points(tail_side, head_side),
      )
    } else {
      let stepx = nodesep_pt
      let stepy = max_double(sizey_param / 2.0 / cnt_f, 2.0)
      let mut sgn = if tp.y >= hp.y { 1.0 } else { -1.0 }
      let point_pair = convert_sides_to_points(tail_side, head_side)
      if (point_pair == 12 || point_pair == 67) && tp.y == hp.y {
        sgn = -sgn
      }
      let mut dx = base0.tail_size.left_pt
      let mut dy = 0.0
      let mut tx = min_double(dx, 3.0 * (tp.x + dx - np.x))
      let mut hx = min_double(dx, 3.0 * (hp.x + dx - np.x))
      let routes : Array[@routing.SelfEdgeRoute] = []
      for i in 0..<cnt {
        let edge = edges[i]
        dx = dx + stepx
        tx = tx + stepx
        hx = hx + stepx
        dy = dy + sgn * stepy
        let points = [
          tp,
          @edge_spline.point(tp.x - tx / 3.0, tp.y + dy),
          @edge_spline.point(np.x - dx, tp.y + dy),
          @edge_spline.point(np.x - dx, (tp.y + hp.y) / 2.0),
          @edge_spline.point(np.x - dx, hp.y - dy),
          @edge_spline.point(hp.x - hx / 3.0, hp.y - dy),
          hp,
        ]
        let mut label_pos : @geom.Point? = None
        let label_width = self_edge_label_width_pt(edge, base0.rankdir)
        if label_width > 0.0 {
          label_pos = Some(@edge_spline.point(np.x - dx - label_width / 2.0, np.y))
          if label_width > stepx {
            dx = dx + (label_width - stepx)
          }
        }
        routes.push({ points, label_pos })
      }
      return routes
    }
  }
  let point_pair = convert_sides_to_points(tail_side, head_side)
  if (tail_side & PORT_SIDE_TOP) != 0 {
    return self_edge_routes_top(
      edges,
      base0,
      nodesep_pt,
      sizey_param,
      point_pair,
    )
  }
  if (tail_side & PORT_SIDE_BOTTOM) != 0 {
    return self_edge_routes_bottom(
      edges,
      base0,
      nodesep_pt,
      sizey_param,
      point_pair,
    )
  }
  self_edge_routes_top(edges, base0, nodesep_pt, sizey_param, point_pair)
}
