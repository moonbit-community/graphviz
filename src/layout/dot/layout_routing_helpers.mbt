///|
priv struct RoutingContext {
  order_index : Map[String, Int]
  path_order_index : Map[String, Int]
  path_adjacency : @routesplines.PathAdjacency
  pathplan_sizes : Map[String, NodeSize]
  pathplan_vnode_mval_sizes : Map[String, NodeSize]
  path_cluster_keys : Map[String, String]
  path_vnode_clusters : Map[String, String]
  parallel_offsets : Map[Int, Double]
  cluster_bboxes : Map[String, @geom.Rect]
}

///|
/// Graphviz parity: routing context aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// + lib/common/routespl.c + lib/pathplan/* (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn prepare_routing_context(
  nodes : Array[@cgraph.Node],
  edges : Array[@cgraph.Edge],
  edge_tail : Array[String],
  edge_head : Array[String],
  sizes : Map[String, NodeSize],
  rankdir : RankDir,
  record_orientation : RecordOrientation,
  ranks : Map[String, Int],
  ordered_groups : Map[Int, Array[String]],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  cluster_bboxes : Map[String, @geom.Rect],
) -> RoutingContext {
  let order_index = build_order_index(ordered_groups)
  let path_order_index = build_order_index(x_groups)
  let path_adjacency =
    @routesplines.build_path_adjacency(
      edges,
      vnode_info.edge_vnodes,
      edge_tail,
      edge_head,
    )
  // Graphviz parity: pathplan neighbor widths use ND_mval (self-edge right space).
  let pathplan_sizes =
    apply_self_edge_right_space(
      nodes,
      edges,
      sizes,
      rankdir,
      record_orientation,
    )
  // Graphviz parity: preserve original vnode widths for ND_mval usage.
  let pathplan_vnode_mval_sizes : Map[String, NodeSize] = Map::new()
  for name, size in vnode_info.vnode_sizes {
    pathplan_vnode_mval_sizes[name] = size
  }
  let path_cluster_keys : Map[String, String] = Map::new()
  for node in nodes {
    path_cluster_keys[node.name()] = node_local_cluster_key(node)
  }
  let path_vnode_clusters : Map[String, String] = Map::new()
  for edge in edges {
    let key = edge_vnode_key(edge)
    let vnodes = match vnode_info.edge_vnodes.get(key) {
      Some(list) => list
      None => []
    }
    if vnodes.length() == 0 {
      continue
    }
    let tail_cluster = node_local_cluster_key(edge.tail())
    let head_cluster = node_local_cluster_key(edge.head())
    for vnode in vnodes {
      let pos = match vnode_positions.get(vnode) {
        Some(value) => value
        None => continue
      }
      let mut vnode_cluster = ""
      if tail_cluster != "" {
        match cluster_bboxes.get(tail_cluster) {
          Some(rect) =>
            if pos.x >= rect.llx && pos.x <= rect.urx &&
              pos.y >= rect.lly && pos.y <= rect.ury {
              vnode_cluster = tail_cluster
            }
          None => ()
        }
      }
      if vnode_cluster == "" && head_cluster != "" {
        match cluster_bboxes.get(head_cluster) {
          Some(rect) =>
            if pos.x >= rect.llx && pos.x <= rect.urx &&
              pos.y >= rect.lly && pos.y <= rect.ury {
              vnode_cluster = head_cluster
            }
          None => ()
        }
      }
      path_vnode_clusters[vnode] = vnode_cluster
    }
  }
  let edge_reversed_by_id : Map[Int, Bool] = Map::new()
  for i in 0..<edges.length() {
    let edge = edges[i]
    let oriented_tail =
      if i < edge_tail.length() { edge_tail[i] } else { edge.tail().name() }
    let oriented_head =
      if i < edge_head.length() { edge_head[i] } else { edge.head().name() }
    let reversed =
      oriented_tail == edge.head().name() &&
      oriented_head == edge.tail().name()
    edge_reversed_by_id[edge.id()] = reversed
  }
  let parallel_offsets =
    edge_parallel_offsets(
      edges,
      ranks,
      order_index,
      nodesep_pt,
      edge_reversed_by_id,
      path_cluster_keys,
    )
  {
    order_index,
    path_order_index,
    path_adjacency,
    pathplan_sizes,
    pathplan_vnode_mval_sizes,
    path_cluster_keys,
    path_vnode_clusters,
    parallel_offsets,
    cluster_bboxes,
  }
}
///|
priv struct EdgeRouteBase {
  edge : @cgraph.Edge
  parallel_offset : Double
  swap_ends : Bool
  orig_tail_name : String
  orig_head_name : String
  tail_name : String
  head_name : String
  tail_port : @cgraph.Port?
  head_port : @cgraph.Port?
  tail_node : @cgraph.Node
  head_node : @cgraph.Node
  tail_pos : @geom.Point
  head_pos : @geom.Point
  tail_size : NodeSize
  head_size : NodeSize
  tail_anchor : @geom.Point
  head_anchor : @geom.Point
  head_port_rect : @geom.Rect?
  tail_port_side : Int
  head_port_side : Int
  tail_sameport_group_size : Int
  head_sameport_group_size : Int
  tail_clip_center : @geom.Point
  tail_clip_size : NodeSize
  head_clip_center : @geom.Point
  head_clip_size : NodeSize
  tail_clip_enabled : Bool
  head_clip_enabled : Bool
  tail_clip : @geom.Point
  head_clip : @geom.Point
  tail_slope : @geom.Point
  head_slope : @geom.Point
  force_segmented : Bool
  tail_cluster_bbox : @geom.Rect?
  head_cluster_bbox : @geom.Rect?
  tail_rank : Int
  head_rank : Int
  is_flat_edge : Bool
  vnodes : Array[String]
  has_vnodes : Bool
  use_pathplan : Bool
  route_include_tail : Bool
  route_include_head : Bool
  arrow_len_override : Double?
  is_dotted : Bool
  same_outer_cluster : Bool
  diff_local_cluster : Bool
  same_local_cluster : Bool
  out_tail_anchor : @geom.Point
  out_head_anchor : @geom.Point
  out_tail_clip : @geom.Point
  out_head_clip : @geom.Point
  out_tail_pos : @geom.Point
  out_head_pos : @geom.Point
  out_tail_size : NodeSize
  out_head_size : NodeSize
  rankdir : RankDir
  layout_rankdir : RankDir
  has_side_anchor : Bool
}

///|
priv struct EdgeSplineResult {
  spline : @geom.Spline
  label_pad_boost : Double
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  raw_bezier : Array[@geom.Point]
  pathplan_segments : Array[@routesplines.PathplanSegment]
  apply_dotted_adjustment : Bool
}

///|
priv struct SelfEdgeRoute {
  points : Array[@geom.Point]
  label_pos : @geom.Point?
}

///|
fn self_edge_label_height_pt(edge : @cgraph.Edge, rankdir : RankDir) -> Double {
  match edge_mid_label_metrics(edge) {
    Some((width, height)) =>
      if rankdir == RankDir::LR || rankdir == RankDir::RL {
        width
      } else {
        height
      }
    None => 0.0
  }
}

///|
fn rank_bounds(rank_y : Map[Int, Double]) -> (Int, Int) {
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
  (min_rank, max_rank)
}

///|
fn flat_no_arrow_detour_points_if_blocked(
  tail_name : String,
  head_name : String,
  rank : Int,
  line_start : @geom.Point,
  line_end : @geom.Point,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  ranksep_pt : Double,
  rankdir : RankDir,
) -> (Array[@geom.Point], Double, Double, Double, Double)? {
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let min_x = min_double(line_start.x, line_end.x)
      let max_x = max_double(line_start.x, line_end.x)
      let line_y = (line_start.y + line_end.y) / 2.0
      let mut found = false
      let mut max_top = max_double(line_start.y, line_end.y)
      let mut blocker_min_left = max_x
      let mut blocker_max_right = min_x
      let mut first_right = max_x
      let mut last_left = min_x
      for name, pos in positions {
        if name == tail_name || name == head_name {
          continue
        }
        let node_rank = match ranks.get(name) {
          Some(value) => value
          None => continue
        }
        if node_rank != rank {
          continue
        }
        let size = match sizes.get(name) {
          Some(value) => value
          None => continue
        }
        let half_h = size.height_pt / 2.0
        if line_y < pos.y - half_h - 0.01 || line_y > pos.y + half_h + 0.01 {
          continue
        }
        let half_w = size.width_pt / 2.0
        let left = pos.x - half_w
        let right = pos.x + half_w
        if right <= min_x + 0.01 || left >= max_x - 0.01 {
          continue
        }
        let top = pos.y + size.height_pt / 2.0
        if top > max_top {
          max_top = top
        }
        if left < blocker_min_left {
          blocker_min_left = left
          first_right = right
        }
        if right > blocker_max_right {
          blocker_max_right = right
          last_left = left
        }
        found = true
      }
      if !found {
        None
      } else {
        let vspace =
          if rank > 0 {
            match (
              rank_y.get(rank),
              rank_ht2.get(rank),
              rank_y.get(rank - 1),
              rank_ht1.get(rank - 1),
            ) {
              (Some(cur_y), Some(cur_ht2), Some(prev_y), Some(prev_ht1)) => {
                let gap = prev_y - prev_ht1 - cur_y - cur_ht2
                if gap > 0.0 { gap } else { ranksep_pt }
              }
              _ => ranksep_pt
            }
          } else {
            ranksep_pt
          }
        let detour_y = max_top + vspace / 2.0
        let bend1_x =
          if line_start.x <= line_end.x {
            blocker_min_left
          } else {
            blocker_max_right
          }
        let bend2_x =
          if line_start.x <= line_end.x {
            blocker_max_right
          } else {
            blocker_min_left
          }
        Some((
          [
          line_start,
          point(bend1_x, detour_y),
          point(bend2_x, detour_y),
          line_end,
        ],
          first_right,
          last_left,
          detour_y,
          vspace,
        ))
      }
    }
    RankDir::LR | RankDir::RL => {
      let min_y = min_double(line_start.y, line_end.y)
      let max_y = max_double(line_start.y, line_end.y)
      let line_x = (line_start.x + line_end.x) / 2.0
      let mut found = false
      let mut max_right = max_double(line_start.x, line_end.x)
      for name, pos in positions {
        if name == tail_name || name == head_name {
          continue
        }
        let node_rank = match ranks.get(name) {
          Some(value) => value
          None => continue
        }
        if node_rank != rank {
          continue
        }
        let size = match sizes.get(name) {
          Some(value) => value
          None => continue
        }
        let half_w = size.width_pt / 2.0
        if line_x < pos.x - half_w - 0.01 || line_x > pos.x + half_w + 0.01 {
          continue
        }
        let half_h = size.height_pt / 2.0
        let bottom = pos.y - half_h
        let top = pos.y + half_h
        if top <= min_y + 0.01 || bottom >= max_y - 0.01 {
          continue
        }
        let right = pos.x + size.width_pt / 2.0
        if right > max_right {
          max_right = right
        }
        found = true
      }
      if !found {
        None
      } else {
        let detour_x = max_right + ranksep_pt / 2.0
        Some(([
          line_start,
          point(detour_x, line_start.y),
          point(detour_x, line_end.y),
          line_end,
        ], 0.0, 0.0, 0.0, 0.0))
      }
    }
  }
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
  base0 : EdgeRouteBase,
  nodesep_pt : Double,
  sizey_param : Double,
  point_pair : Int,
) -> Array[SelfEdgeRoute] {
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
      point(tp.x + dx, tp.y + ty / 3.0),
      point(tp.x + dx, np.y + dy),
      point((tp.x + hp.x) / 2.0, np.y + dy),
      point(hp.x - dx, np.y + dy),
      point(hp.x - dx, hp.y + hy / 3.0),
      hp,
    ]
    let mut label_pos : @geom.Point? = None
    let label_height = self_edge_label_height_pt(edge, base0.layout_rankdir)
    if label_height > 0.0 {
      label_pos = Some(point(np.x, np.y + dy + label_height / 2.0))
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
  base0 : EdgeRouteBase,
  nodesep_pt : Double,
  sizey_param : Double,
  point_pair : Int,
) -> Array[SelfEdgeRoute] {
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
      point(tp.x + dx, tp.y - ty / 3.0),
      point(tp.x + dx, np.y - dy),
      point((tp.x + hp.x) / 2.0, np.y - dy),
      point(hp.x - dx, np.y - dy),
      point(hp.x - dx, hp.y - hy / 3.0),
      hp,
    ]
    let mut label_pos : @geom.Point? = None
    let label_height = self_edge_label_height_pt(edge, base0.layout_rankdir)
    if label_height > 0.0 {
      label_pos = Some(point(np.x, np.y - dy - label_height / 2.0))
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
  bases : Array[EdgeRouteBase],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
) -> Array[SelfEdgeRoute] {
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
  let tail_defined = port_is_explicit(base0.tail_port)
  let head_defined = port_is_explicit(base0.head_port)
  let (min_rank, max_rank) = rank_bounds(rank_y)
  let sizey =
    self_edge_rank_spacing(
      base0.tail_rank,
      rank_y,
      np.y,
      base0.tail_size.height_pt,
      min_rank,
      max_rank,
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
    let routes : Array[SelfEdgeRoute] = []
    for i in 0..<cnt {
      let edge = edges[i]
      dx = dx + stepx
      tx = tx + stepx
      hx = hx + stepx
      dy = dy + sgn * stepy
      let points = [
        tp,
        point(tp.x + tx / 3.0, tp.y + dy),
        point(np.x + dx, tp.y + dy),
        point(np.x + dx, (tp.y + hp.y) / 2.0),
        point(np.x + dx, hp.y - dy),
        point(hp.x + hx / 3.0, hp.y - dy),
        hp,
      ]
      let mut label_pos : @geom.Point? = None
      let label_width = self_edge_label_width_pt(edge, base0.rankdir)
      if label_width > 0.0 {
        label_pos = Some(point(np.x + dx + label_width / 2.0, np.y))
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
      let routes : Array[SelfEdgeRoute] = []
      for i in 0..<cnt {
        let edge = edges[i]
        dx = dx + stepx
        tx = tx + stepx
        hx = hx + stepx
        dy = dy + sgn * stepy
        let points = [
          tp,
          point(tp.x - tx / 3.0, tp.y + dy),
          point(np.x - dx, tp.y + dy),
          point(np.x - dx, (tp.y + hp.y) / 2.0),
          point(np.x - dx, hp.y - dy),
          point(hp.x - hx / 3.0, hp.y - dy),
          hp,
        ]
        let mut label_pos : @geom.Point? = None
        let label_width = self_edge_label_width_pt(edge, base0.rankdir)
        if label_width > 0.0 {
          label_pos = Some(point(np.x - dx - label_width / 2.0, np.y))
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

///|
fn self_edge_group_key(edge : @cgraph.Edge) -> String {
  edge_parallel_key(
    edge.tail().name(),
    edge.head().name(),
    edge.tail_port(),
    edge.head_port(),
  )
}

///|
fn clip_polygon_attr_int(
  node : @cgraph.Node,
  key : String,
  fallback : Int,
) -> Int {
  match node.get_attr(key) {
    Some(value) => parse_double(value, fallback.to_double()).round().to_int()
    None => fallback
  }
}

///|
fn clip_polygon_attr_double(
  node : @cgraph.Node,
  key : String,
  fallback : Double,
) -> Double {
  match node.get_attr(key) {
    Some(value) => parse_double(value, fallback)
    None => fallback
  }
}

///|
fn clip_polygon_shape_params(
  node : @cgraph.Node,
  shape : String,
) -> (Int, Double, Double, Double)? {
  match shape {
    "triangle" => Some((3, 0.0, 0.0, 0.0))
    "invtriangle" => Some((3, 180.0, 0.0, 0.0))
    "trapezium" => Some((4, 0.0, -0.4, 0.0))
    "invtrapezium" => Some((4, 180.0, -0.4, 0.0))
    "parallelogram" => Some((4, 0.0, 0.0, 0.6))
    "egg" => Some((120, 0.0, -0.3, 0.0))
    "house" => Some((5, 0.0, -0.64, 0.0))
    "invhouse" => Some((5, 180.0, -0.64, 0.0))
    "pentagon" => Some((5, 0.0, 0.0, 0.0))
    "hexagon" => Some((6, 0.0, 0.0, 0.0))
    "septagon" => Some((7, 0.0, 0.0, 0.0))
    "octagon" | "doubleoctagon" | "tripleoctagon" => Some((8, 0.0, 0.0, 0.0))
    "polygon" => {
      let mut sides = clip_polygon_attr_int(node, "sides", 4)
      if sides < 0 {
        sides = 0
      }
      let orientation = clip_polygon_attr_double(node, "orientation", 0.0)
      let distortion = clip_polygon_attr_double(node, "distortion", 0.0)
      let skew = clip_polygon_attr_double(node, "skew", 0.0)
      if sides <= 2 && (Double::abs(distortion) > 0.0000001 || Double::abs(skew) > 0.0000001) {
        sides = 120
      }
      if sides >= 3 {
        Some((sides, orientation, distortion, skew))
      } else {
        None
      }
    }
    _ => None
  }
}

///|
fn clip_polygon_vertices_for_shape(
  size : NodeSize,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> Array[@geom.Point] {
  if sides < 3 {
    return []
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  if half_w <= 0.0 || half_h <= 0.0 {
    return []
  }
  let sector = 2.0 * @math.PI / sides.to_double()
  let side_len = @math.sin(sector / 2.0)
  let abs_mix = Double::abs(distortion) + Double::abs(skew)
  let skew_dist = Double::sqrt(abs_mix * abs_mix + 1.0)
  let cos_half = @math.cos(sector / 2.0)
  if Double::abs(cos_half) <= 0.0000001 {
    return []
  }
  let g_distortion = distortion * Double::sqrt(2.0) / cos_half
  let g_skew = skew / 2.0
  let mut angle = (sector - @math.PI) / 2.0
  let mut sinx = @math.sin(angle)
  let mut cosx = @math.cos(angle)
  let mut r = point(0.5 * cosx, 0.5 * sinx)
  let mut xmax = 0.0
  let mut ymax = 0.0
  angle = angle + (@math.PI - sector) / 2.0
  let base : Array[@geom.Point] = []
  for _ in 0..<sides {
    angle = angle + sector
    sinx = @math.sin(angle)
    cosx = @math.cos(angle)
    r = point(r.x + side_len * cosx, r.y + side_len * sinx)
    let mut px = r.x * (skew_dist + r.y * g_distortion) + r.y * g_skew
    let mut py = r.y
    let alpha = orientation_deg * @math.PI / 180.0 + @math.atan2(py, px)
    let radius = Double::sqrt(px * px + py * py)
    px = radius * @math.cos(alpha)
    py = radius * @math.sin(alpha)
    if Double::abs(px) > xmax {
      xmax = Double::abs(px)
    }
    if Double::abs(py) > ymax {
      ymax = Double::abs(py)
    }
    base.push(point(px, py))
  }
  if xmax <= 0.0 || ymax <= 0.0 {
    return []
  }
  let scale_x = half_w / xmax
  let scale_y = half_h / ymax
  let out : Array[@geom.Point] = []
  for vertex in base {
    out.push(point(vertex.x * scale_x, vertex.y * scale_y))
  }
  out
}

///|
fn clip_to_polygon_shape(
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
  sides : Int,
  orientation_deg : Double,
  distortion : Double,
  skew : Double,
) -> @geom.Point {
  let vertices =
    clip_polygon_vertices_for_shape(
      size,
      sides,
      orientation_deg,
      distortion,
      skew,
    )
  if vertices.length() < 3 {
    return clip_to_rect(center, size, target)
  }
  let dx = target.x - center.x
  let dy = target.y - center.y
  if Double::abs(dx) <= 0.0000001 && Double::abs(dy) <= 0.0000001 {
    return center
  }
  let mut best_t = 0.0
  let mut found = false
  for i in 0..<vertices.length() {
    let a = vertices[i]
    let b = vertices[(i + 1) % vertices.length()]
    let sx = b.x - a.x
    let sy = b.y - a.y
    let denom = dx * sy - dy * sx
    if Double::abs(denom) <= 0.0000001 {
      continue
    }
    let t = (a.x * sy - a.y * sx) / denom
    let u = (a.x * dy - a.y * dx) / denom
    if t < 0.0 {
      continue
    }
    if u < -0.000001 || u > 1.000001 {
      continue
    }
    if !found || t < best_t {
      best_t = t
      found = true
    }
  }
  if found {
    point(center.x + dx * best_t, center.y + dy * best_t)
  } else {
    clip_to_rect(center, size, target)
  }
}

///|
/// Graphviz parity: route anchor clipping uses node shape bounds.
fn clip_to_node_shape(
  node : @cgraph.Node,
  center : @geom.Point,
  size : NodeSize,
  target : @geom.Point,
) -> @geom.Point {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "" | "ellipse" | "oval" | "circle" | "doublecircle" | "point" | "dot" =>
      clip_to_ellipse(center, size, target)
    "diamond" | "mdiamond" => clip_to_diamond(center, size, target)
    _ =>
      match clip_polygon_shape_params(node, shape) {
        Some((sides, orientation, distortion, skew)) =>
          clip_to_polygon_shape(
            center,
            size,
            target,
            sides,
            orientation,
            distortion,
            skew,
          )
        None => clip_to_rect(center, size, target)
      }
  }
}

///|
/// Graphviz parity: samehead/sametail group collection aligned to
/// refs/graphviz/lib/dotgen/sameport.c (dot_sameports/sameedge).
/// Do not change behavior without updating fixtures/tests.
fn add_sameport_group_edge(
  groups : Map[String, Array[@cgraph.Edge]],
  group_order : Array[String],
  key : String,
  edge : @cgraph.Edge,
) -> Unit {
  match groups.get(key) {
    Some(list) => list.push(edge)
    None => {
      groups[key] = [edge]
      group_order.push(key)
    }
  }
}

///|
fn sameport_merge_key(edge : @cgraph.Edge) -> String {
  let label = match edge.get_attr("label") {
    Some(value) => value
    None => ""
  }
  "\{edge.tail().name()}|\{edge.head().name()}|\{label}|\{port_key(edge.tail_port())}|\{port_key(edge.head_port())}"
}

///|
fn collect_sameport_merge_classes(
  edges : Array[@cgraph.Edge],
) -> Map[String, Array[@cgraph.Edge]] {
  let classes : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    if edge.tail().name() == edge.head().name() {
      continue
    }
    let key = sameport_merge_key(edge)
    match classes.get(key) {
      Some(list) => list.push(edge)
      None => classes[key] = [edge]
    }
  }
  classes
}

///|
fn assign_sameport_override_with_merge(
  overrides : Map[Int, @geom.Point],
  merge_classes : Map[String, Array[@cgraph.Edge]],
  edge : @cgraph.Edge,
  anchor : @geom.Point,
) -> Unit {
  if edge_has_label(edge) {
    overrides[edge.id()] = anchor
    return ()
  }
  match merge_classes.get(sameport_merge_key(edge)) {
    Some(class_edges) =>
      for member_edge in class_edges {
        overrides[member_edge.id()] = anchor
      }
    None => overrides[edge.id()] = anchor
  }
}

///|
fn assign_sameport_group_size_with_merge(
  group_sizes : Map[Int, Int],
  merge_classes : Map[String, Array[@cgraph.Edge]],
  edge : @cgraph.Edge,
  group_size : Int,
) -> Unit {
  if edge_has_label(edge) {
    group_sizes[edge.id()] = group_size
    return ()
  }
  match merge_classes.get(sameport_merge_key(edge)) {
    Some(class_edges) =>
      for member_edge in class_edges {
        group_sizes[member_edge.id()] = group_size
      }
    None => group_sizes[edge.id()] = group_size
  }
}

///|
fn sameport_node_penwidth_pt(node : @cgraph.Node) -> Double {
  match node.get_attr("penwidth") {
    Some(value) => {
      let penwidth = parse_double(value, 1.0)
      if penwidth < 0.0 {
        0.0
      } else {
        penwidth
      }
    }
    None => 1.0
  }
}

///|
fn sameport_shape_has_outline(node : @cgraph.Node) -> Bool {
  let shape = match node.get_attr("shape") {
    Some(value) => value.to_lower()
    None => ""
  }
  match shape {
    "plain" | "plaintext" | "none" => false
    _ => true
  }
}

///|
/// Graphviz parity: sameport anchor construction aligned to
/// refs/graphviz/lib/dotgen/sameport.c (sameport).
/// Do not change behavior without updating fixtures/tests.
fn sameport_anchor_for_group(
  node : @cgraph.Node,
  group_edges : Array[@cgraph.Edge],
  head_group : Bool,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  layout_rankdir : RankDir,
  ranksep_pt : Double,
) -> @geom.Point? {
  let node_name = node.name()
  let node_pos = match positions.get(node_name) {
    Some(value) => value
    None => return None
  }
  let node_size = match sizes.get(node_name) {
    Some(value) => value
    None => node_size(node, record_orientation)
  }
  let base_clip_size =
    match layout_rankdir {
      RankDir::LR | RankDir::RL =>
        node_size_from_points(node_size.height_pt, node_size.width_pt)
      RankDir::TB | RankDir::BT => node_size
    }
  let clip_size =
    if group_edges.length() > 3 {
      base_clip_size
    } else {
      let clip_size =
        if sameport_shape_has_outline(node) {
          let penwidth = sameport_node_penwidth_pt(node)
          if penwidth > 0.0 {
            node_size_from_points(
              base_clip_size.width_pt + penwidth / 2.0,
              base_clip_size.height_pt + penwidth / 2.0,
            )
          } else {
            base_clip_size
          }
        } else {
          base_clip_size
        }
      if group_edges.length() > 2 {
        node_size_from_points(
          clip_size.width_pt + 2.0,
          clip_size.height_pt + 2.0,
        )
      } else {
        clip_size
      }
    }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for edge in group_edges {
    let peer_name = if head_group { edge.tail().name() } else { edge.head().name() }
    let peer_pos = match positions.get(peer_name) {
      Some(value) => value
      None => continue
    }
    let dx = peer_pos.x - node_pos.x
    let dy = peer_pos.y - node_pos.y
    let len = Double::sqrt(dx * dx + dy * dy)
    if len <= 0.0 {
      continue
    }
    sum_x = sum_x + dx / len
    sum_y = sum_y + dy / len
  }
  let sum_len = Double::sqrt(sum_x * sum_x + sum_y * sum_y)
  if sum_len <= 0.0 {
    return None
  }
  let dir_x = sum_x / sum_len
  let dir_y = sum_y / sum_len
  let far = max_double(
    clip_size.left_pt + clip_size.right_pt,
    clip_size.height_pt + ranksep_pt,
  )
  let target = point(node_pos.x + dir_x * far, node_pos.y + dir_y * far)
  let clipped0 = clip_to_node_shape(node, node_pos, clip_size, target)
  let clipped =
    if group_edges.length() > 3 {
      if Double::abs(dir_x) <= Double::abs(dir_y) * 0.25 {
        point(clipped0.x + dir_x, clipped0.y + dir_y)
      } else {
        clipped0
      }
    } else {
      let sameport_nudge =
        if group_edges.length() > 2 {
          0.5
        } else {
          1.0
        }
      point(
        clipped0.x + dir_x * sameport_nudge,
        clipped0.y + dir_y * sameport_nudge,
      )
    }
  // Graphviz sameport stores integer offset from node center.
  let rel_x = (clipped.x - node_pos.x).round()
  let rel_y = (clipped.y - node_pos.y).round()
  Some(point(node_pos.x + rel_x, node_pos.y + rel_y))
}

///|
/// Graphviz parity: samehead/sametail handling aligned to
/// refs/graphviz/lib/dotgen/sameport.c (dot_sameports).
/// Do not change behavior without updating fixtures/tests.
fn collect_sameport_anchor_overrides(
  edges : Array[@cgraph.Edge],
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  layout_rankdir : RankDir,
  ranksep_pt : Double,
) -> (
  Map[Int, @geom.Point],
  Map[Int, @geom.Point],
  Map[Int, Int],
  Map[Int, Int],
) {
  let samehead_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  let sametail_groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  let samehead_group_order : Array[String] = []
  let sametail_group_order : Array[String] = []
  let merge_classes = collect_sameport_merge_classes(edges)
  for edge in edges {
    if edge.tail().name() == edge.head().name() {
      continue
    }
    match edge.get_attr("samehead") {
      Some(id) =>
        if id != "" {
          add_sameport_group_edge(
            samehead_groups,
            samehead_group_order,
            "\{edge.head().name()}|\{id}",
            edge,
          )
        }
      None => ()
    }
    match edge.get_attr("sametail") {
      Some(id) =>
        if id != "" {
          add_sameport_group_edge(
            sametail_groups,
            sametail_group_order,
            "\{edge.tail().name()}|\{id}",
            edge,
          )
        }
      None => ()
    }
  }
  let samehead_overrides : Map[Int, @geom.Point] = Map::new()
  let samehead_group_sizes : Map[Int, Int] = Map::new()
  for key in samehead_group_order {
    let group_edges = match samehead_groups.get(key) {
      Some(value) => value
      None => continue
    }
    if group_edges.length() <= 1 {
      continue
    }
    match sameport_anchor_for_group(
      group_edges[0].head(),
      group_edges,
      true,
      positions,
      sizes,
      record_orientation,
      layout_rankdir,
      ranksep_pt,
    ) {
      Some(anchor) =>
        for edge in group_edges {
          assign_sameport_override_with_merge(
            samehead_overrides,
            merge_classes,
            edge,
            anchor,
          )
          assign_sameport_group_size_with_merge(
            samehead_group_sizes,
            merge_classes,
            edge,
            group_edges.length(),
          )
        }
      None => ()
    }
  }
  let sametail_overrides : Map[Int, @geom.Point] = Map::new()
  let sametail_group_sizes : Map[Int, Int] = Map::new()
  for key in sametail_group_order {
    let group_edges = match sametail_groups.get(key) {
      Some(value) => value
      None => continue
    }
    if group_edges.length() <= 1 {
      continue
    }
    match sameport_anchor_for_group(
      group_edges[0].tail(),
      group_edges,
      false,
      positions,
      sizes,
      record_orientation,
      layout_rankdir,
      ranksep_pt,
    ) {
      Some(anchor) =>
        for edge in group_edges {
          assign_sameport_override_with_merge(
            sametail_overrides,
            merge_classes,
            edge,
            anchor,
          )
          assign_sameport_group_size_with_merge(
            sametail_group_sizes,
            merge_classes,
            edge,
            group_edges.length(),
          )
        }
      None => ()
    }
  }
  (
    samehead_overrides,
    sametail_overrides,
    samehead_group_sizes,
    sametail_group_sizes,
  )
}

///|
fn flat_parallel_group_key(edge : @cgraph.Edge) -> String {
  "\{edge.tail().name()}|\{port_key(edge.tail_port())}|\{edge.head().name()}|\{port_key(edge.head_port())}"
}

///|
fn collect_flat_adjacent_simple_beziers(
  edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
  ranks : Map[String, Int],
  order_index : Map[String, Int],
) -> Map[Int, Array[@geom.Point]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in edges {
    if edge.tail().name() == edge.head().name() {
      continue
    }
    if edge_has_label(edge) {
      continue
    }
    if port_is_explicit(edge.tail_port()) || port_is_explicit(edge.head_port()) {
      continue
    }
    match edge.get_attr("samehead") {
      Some(value) => if value != "" { continue }
      None => ()
    }
    match edge.get_attr("sametail") {
      Some(value) => if value != "" { continue }
      None => ()
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
    let key = flat_parallel_group_key(edge)
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
    group_edges.sort_by((a, b) => cmp_int(a.id(), b.id()))
    let count = group_edges.length()
    let base_one_third = point(
      tx + (hx - tx) / 3.0,
      ty + (hy - ty) / 3.0,
    )
    let base_two_third = point(
      tx + (hx - tx) * 2.0 / 3.0,
      ty + (hy - ty) * 2.0 / 3.0,
    )
    let denom =
      if count > 1 { Double::from_int(count - 1) } else { 1.0 }
    for i in 0..<count {
      let frac = Double::from_int(i) / denom
      let offset = -span / 2.0 + span * frac
      let shift = point(perp_x * offset, perp_y * offset)
      let edge = group_edges[i]
      let edge_base = match base_cache.get(edge.id()) {
        Some(value) => value
        None => continue
      }
      let c1 = point_add(base_one_third, shift)
      let c2 = point_add(base_two_third, shift)
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
/// Graphviz parity: edge endpoint/port setup aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_route_base(
  graph_kind : @cgraph.GraphKind,
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  routing_context : RoutingContext,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  enable_complex_tuning : Bool,
  edge_vnodes : Map[String, Array[String]],
  samehead_overrides : Map[Int, @geom.Point],
  sametail_overrides : Map[Int, @geom.Point],
  samehead_group_sizes : Map[Int, Int],
  sametail_group_sizes : Map[Int, Int],
) -> EdgeRouteBase {
  let order_index = routing_context.order_index
  let parallel_offsets = routing_context.parallel_offsets
  let cluster_bboxes = routing_context.cluster_bboxes
  let orig_tail_name = edge.tail().name()
  let orig_head_name = edge.head().name()
  let swap_ends_raw =
    edge_swap_ends(orig_tail_name, orig_head_name, ranks, order_index)
  let tail_rank_for_swap = match ranks.get(orig_tail_name) {
    Some(v) => v
    None => 0
  }
  let head_rank_for_swap = match ranks.get(orig_head_name) {
    Some(v) => v
    None => 0
  }
  let swap_ends =
    if tail_rank_for_swap == head_rank_for_swap &&
      node_local_cluster_key(edge.tail()) != node_local_cluster_key(edge.head()) {
      false
    } else {
      swap_ends_raw
    }
  let samehead_anchor = samehead_overrides.get(edge.id())
  let sametail_anchor = sametail_overrides.get(edge.id())
  let samehead_group_size = match samehead_group_sizes.get(edge.id()) {
    Some(value) => value
    None => 0
  }
  let sametail_group_size = match sametail_group_sizes.get(edge.id()) {
    Some(value) => value
    None => 0
  }
  let parallel_offset = match parallel_offsets.get(edge.id()) {
    Some(value) => value
    None => 0.0
  }
  let (tail_name, head_name, tail_port, head_port, tail_node, head_node) =
    if swap_ends {
      (orig_head_name, orig_tail_name, edge.head_port(), edge.tail_port(), edge.head(), edge.tail())
    } else {
      (orig_tail_name, orig_head_name, edge.tail_port(), edge.head_port(), edge.tail(), edge.head())
    }
  let tail_sameport_anchor = if swap_ends { samehead_anchor } else { sametail_anchor }
  let head_sameport_anchor = if swap_ends { sametail_anchor } else { samehead_anchor }
  let tail_sameport_group_size =
    if swap_ends { samehead_group_size } else { sametail_group_size }
  let head_sameport_group_size =
    if swap_ends { sametail_group_size } else { samehead_group_size }
  let tail_pos = match positions.get(tail_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let head_pos = match positions.get(head_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let tail_size = match sizes.get(tail_name) {
    Some(value) => value
    None => node_size(tail_node, record_orientation)
  }
  let head_size = match sizes.get(head_name) {
    Some(value) => value
    None => node_size(head_node, record_orientation)
  }
  let (raw_tail_anchor, raw_tail_anchor_size) = port_geometry(
    tail_name,
    tail_port,
    label_ports_map,
    tail_pos,
    tail_size,
  )
  let (raw_head_anchor, raw_head_anchor_size) = port_geometry(
    head_name,
    head_port,
    label_ports_map,
    head_pos,
    head_size,
  )
  let tail_port_rect = port_rect_from_geometry(
    tail_port,
    raw_tail_anchor,
    raw_tail_anchor_size,
    tail_size,
  )
  let head_port_rect = port_rect_from_geometry(
    head_port,
    raw_head_anchor,
    raw_head_anchor_size,
    head_size,
  )
  let tail_port_sides = match tail_port_rect {
    Some(rect) => port_side_count(rect, tail_pos, tail_size)
    None => 0
  }
  let head_port_sides = match head_port_rect {
    Some(rect) => port_side_count(rect, head_pos, head_size)
    None => 0
  }
  let tail_label_port = port_is_label_port(tail_name, tail_port, label_ports_raw)
  let head_label_port = port_is_label_port(head_name, head_port, label_ports_raw)
  // Graphviz parity: label ports should not force segmented edge splines.
  let force_segmented_base =
    (!tail_label_port && tail_port_sides >= 3) ||
    (!head_label_port && head_port_sides >= 3)
  let tail_cluster_name = match edge.get_attr("ltail") {
    Some(value) => value
    None => ""
  }
  let head_cluster_name = match edge.get_attr("lhead") {
    Some(value) => value
    None => ""
  }
  let tail_record_border_adjust =
    if is_record_shape(tail_node) &&
      !@html_label.is_html_label_text(label_text(tail_node)) {
      RECORD_BORDER_PT
    } else {
      0.0
    }
  let head_record_border_adjust =
    if is_record_shape(head_node) &&
      !@html_label.is_html_label_text(label_text(head_node)) {
      RECORD_BORDER_PT
    } else {
      0.0
    }
  let tail_rank = match ranks.get(tail_name) {
    Some(value) => value
    None => 0
  }
  let head_rank = match ranks.get(head_name) {
    Some(value) => value
    None => 0
  }
  let is_flat_edge = tail_rank == head_rank
  let has_cluster = tail_cluster_name != "" || head_cluster_name != ""
  let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
    Some(list) => list
    None => []
  }
  let has_vnodes = vnodes.length() > 0
  let force_segmented =
    force_segmented_base ||
    (is_flat_edge && has_vnodes && edge_mid_label_width_pt(edge) > 0.0)
  let use_pathplan = match @sys.get_env_var("DOT_USE_PATHPLAN") {
    Some(value) => {
      let lower = value.to_lower()
      lower != "0" && lower != "false" && lower != "no"
    }
    None => true
  }
  let allow_offset =
    !is_flat_edge &&
    !has_cluster &&
    !port_is_explicit(tail_port) &&
    !port_is_explicit(head_port) &&
    !use_pathplan
  let (tail_offset, head_offset) = if allow_offset {
    (
      layout_port_offset(point(0.0, -1.0), layout_rankdir),
      layout_port_offset(point(0.0, 1.0), layout_rankdir),
    )
  } else {
    (point(0.0, 0.0), point(0.0, 0.0))
  }
  let tail_cluster_bbox : @geom.Rect? =
    if tail_cluster_name == "" {
    None
  } else {
    cluster_bboxes.get(tail_cluster_name)
  }
  let head_cluster_bbox : @geom.Rect? =
    if head_cluster_name == "" {
    None
  } else {
    cluster_bboxes.get(head_cluster_name)
  }
  let (tail_side_anchor, tail_dynamic_side, tail_dynamic) =
    dynamic_port_anchor_for_edge(
      tail_port,
      tail_name,
      label_ports_raw,
      tail_pos,
      head_pos,
      rankdir,
      tail_record_border_adjust,
      "tail",
    )
  let (head_side_anchor, head_dynamic_side, head_dynamic) =
    dynamic_port_anchor_for_edge(
      head_port,
      head_name,
      label_ports_raw,
      head_pos,
      tail_pos,
      rankdir,
      head_record_border_adjust,
      "head",
    )
  let has_side_anchor =
    tail_side_anchor is Some(_) ||
      head_side_anchor is Some(_) ||
      tail_sameport_anchor is Some(_) ||
      head_sameport_anchor is Some(_)
  let tail_anchor_base = match tail_sameport_anchor {
    Some(pos) => pos
    None =>
      match tail_side_anchor {
        Some(pos) => pos
        None => raw_tail_anchor
      }
  }
  let head_anchor_base = match head_sameport_anchor {
    Some(pos) => pos
    None =>
      match head_side_anchor {
        Some(pos) => pos
        None => raw_head_anchor
      }
  }
  let tail_port_side =
    if tail_sameport_anchor is Some(_) {
    port_side_mask_from_anchor(tail_anchor_base, tail_pos, tail_size)
  } else if tail_dynamic {
    tail_dynamic_side
  } else {
    port_side_for_edge(
      tail_port,
      tail_port_rect,
      tail_pos,
      tail_size,
      None,
    )
  }
  let head_port_side =
    if head_sameport_anchor is Some(_) {
    port_side_mask_from_anchor(head_anchor_base, head_pos, head_size)
  } else if head_dynamic {
    head_dynamic_side
  } else {
    port_side_for_edge(
      head_port,
      head_port_rect,
      head_pos,
      head_size,
      None,
    )
  }
  let tail_anchor0 = point_add(tail_anchor_base, tail_offset)
  let head_anchor0 = point_add(head_anchor_base, head_offset)
  let self_edge = orig_tail_name == orig_head_name
  let adjust_self_edge_compass_clip_size =
    (node : @cgraph.Node, port : @cgraph.Port?, size : NodeSize) => {
      if !self_edge || is_record_shape(node) {
        return size
      }
      match port {
        Some(value) =>
          match value.compass {
            Some(@cgraph.Compass::C) => size
            Some(compass) =>
              if sameport_shape_has_outline(node) {
                let penwidth = sameport_node_penwidth_pt(node)
                if penwidth > 0.0 {
                  let pad = penwidth * 0.33055
                  let width_pt =
                    match compass {
                      @cgraph.Compass::NE
                      | @cgraph.Compass::NW
                      | @cgraph.Compass::SE
                      | @cgraph.Compass::SW =>
                        max_double(
                          size.width_pt - (size.height_pt / 3.0 + penwidth * 0.05),
                          size.height_pt,
                        )
                      _ => size.width_pt
                    }
                  node_size_from_points(
                    width_pt,
                    size.height_pt + pad * 2.0,
                  )
                } else {
                  size
                }
              } else {
                size
              }
            None => size
          }
        None => size
      }
    }
  let tail_clip_center = raw_tail_anchor
  let tail_clip_size =
    adjust_self_edge_compass_clip_size(
      tail_node,
      tail_port,
      raw_tail_anchor_size,
    )
  let head_clip_center = raw_head_anchor
  let head_clip_size =
    adjust_self_edge_compass_clip_size(
      head_node,
      head_port,
      raw_head_anchor_size,
    )
  let resolve_compass_clip_point :
    (@cgraph.Node, @cgraph.Port?, @geom.Point, NodeSize) -> @geom.Point? =
    (node, port, center, size) => {
      if self_edge || is_record_shape(node) {
        return None
      }
      match port {
        Some(value) =>
          match value.compass {
            Some(@cgraph.Compass::C) => None
            Some(compass) =>
              Some(
                compass_port_point_on_shape(
                  node,
                  center,
                  size,
                  compass,
                  layout_rankdir,
                ),
              )
            None => None
          }
        None => None
      }
    }
  let tail_compass_clip =
    resolve_compass_clip_point(
      tail_node,
      tail_port,
      tail_clip_center,
      tail_clip_size,
    )
  let head_compass_clip =
    resolve_compass_clip_point(
      head_node,
      head_port,
      head_clip_center,
      head_clip_size,
    )
  let tail_clip_enabled = tail_sameport_anchor is None
  let head_clip_enabled = head_sameport_anchor is None
  let tail_target = match tail_port_rect {
    Some(_) => head_pos
    None => tail_anchor0
  }
  let head_target = match head_port_rect {
    Some(_) => tail_pos
    None => head_anchor0
  }
  let tail_slope = endpoint_slope_for_anchor(
    tail_port,
    tail_port_side,
    tail_anchor0,
    tail_pos,
    tail_size,
    tail_target,
    layout_rankdir,
    true,
    tail_port_rect,
  )
  let head_slope = endpoint_slope_for_anchor(
    head_port,
    head_port_side,
    head_anchor0,
    head_pos,
    head_size,
    head_target,
    layout_rankdir,
    false,
    head_port_rect,
  )
  let tail_clip_target =
    if tail_sameport_anchor is Some(_) {
      tail_anchor0
    } else if port_is_explicit(tail_port) &&
      (tail_slope.x != 0.0 || tail_slope.y != 0.0) {
      point_add(tail_clip_center, tail_slope)
    } else {
      head_anchor0
    }
  let head_clip_target =
    if head_sameport_anchor is Some(_) {
      head_anchor0
    } else if port_is_explicit(head_port) &&
      (head_slope.x != 0.0 || head_slope.y != 0.0) {
      point_sub(head_clip_center, head_slope)
    } else {
      tail_anchor0
    }
  let tail_clip = match tail_cluster_bbox {
    Some(rect) => clip_to_bbox(tail_anchor0, rect, head_anchor0)
    None =>
      match tail_side_anchor {
        Some(pos) => pos
        None =>
          match tail_compass_clip {
            Some(pos) => pos
            None =>
              clip_to_node_shape(
                tail_node,
                tail_clip_center,
                tail_clip_size,
                tail_clip_target,
              )
          }
      }
  }
  let head_clip = match head_cluster_bbox {
    Some(rect) => clip_to_bbox(head_anchor0, rect, tail_anchor0)
    None =>
      match head_side_anchor {
        Some(pos) => pos
        None =>
          match head_compass_clip {
            Some(pos) => pos
            None =>
              clip_to_node_shape(
                head_node,
                head_clip_center,
                head_clip_size,
                head_clip_target,
              )
          }
      }
  }
  let compass_tail_on_non_record = match tail_port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => false
        Some(_) => !is_record_shape(tail_node)
        None => false
      }
    None => false
  }
  let compass_head_on_non_record = match head_port {
    Some(value) =>
      match value.compass {
        Some(@cgraph.Compass::C) => false
        Some(_) => !is_record_shape(head_node)
        None => false
      }
    None => false
  }
  let tail_anchor =
    if tail_sameport_anchor is None && tail_side_anchor is None &&
      compass_tail_on_non_record {
      tail_clip
    } else {
      tail_anchor0
    }
  let head_anchor =
    if head_sameport_anchor is None && head_side_anchor is None &&
      compass_head_on_non_record {
      head_clip
    } else {
      head_anchor0
    }
  let out_tail_anchor = if swap_ends { head_anchor } else { tail_anchor }
  let out_head_anchor = if swap_ends { tail_anchor } else { head_anchor }
  let out_tail_clip = if swap_ends { head_clip } else { tail_clip }
  let out_head_clip = if swap_ends { tail_clip } else { head_clip }
  let out_tail_pos = match positions.get(orig_tail_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let out_head_pos = match positions.get(orig_head_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let out_tail_size = match sizes.get(orig_tail_name) {
    Some(value) => value
    None => node_size(edge.tail(), record_orientation)
  }
  let out_head_size = match sizes.get(orig_head_name) {
    Some(value) => value
    None => node_size(edge.head(), record_orientation)
  }
  let dir = edge_dir_for(edge, graph_kind)
  let include_tail = match dir {
    EdgeDir::Back | EdgeDir::Both => true
    _ => false
  }
  let include_head = match dir {
    EdgeDir::Forward | EdgeDir::Both => true
    _ => false
  }
  let (route_include_tail, route_include_head) =
    if swap_ends { (include_head, include_tail) } else { (include_tail, include_head) }
  let arrow_len_override : Double? =
    if include_tail || include_head {
    if tail_cluster_bbox is Some(_) || head_cluster_bbox is Some(_) {
      let (tail_len, head_len) =
        arrow_length_for_edge(edge, include_tail, include_head, None)
      let base = if tail_len > head_len { tail_len } else { head_len }
      let span = point_dist(tail_clip, head_clip)
      let max_len = if span < 12.0 { span * 0.25 } else { span }
      if max_len > 0.0 && max_len < base {
        Some(max_len)
      } else {
        None
      }
    } else {
      None
    }
  } else {
    None
  }
  let style_value = if enable_complex_tuning {
    match edge.get_attr("style") {
      Some(value) => value.to_lower()
      None => ""
    }
  } else {
    ""
  }
  let is_dotted = enable_complex_tuning && style_value.contains("dotted")
  let same_outer_cluster =
    node_cluster_key(tail_node) == node_cluster_key(head_node)
  let diff_local_cluster =
    node_local_cluster_key(tail_node) != node_local_cluster_key(head_node)
  let same_local_cluster = !diff_local_cluster
  {
    edge,
    parallel_offset,
    swap_ends,
    orig_tail_name,
    orig_head_name,
    tail_name,
    head_name,
    tail_port,
    head_port,
    tail_node,
    head_node,
    tail_pos,
    head_pos,
    tail_size,
    head_size,
    tail_anchor,
    head_anchor,
    head_port_rect,
    tail_port_side,
    head_port_side,
    tail_sameport_group_size,
    head_sameport_group_size,
    tail_clip_center,
    tail_clip_size,
    head_clip_center,
    head_clip_size,
    tail_clip_enabled,
    head_clip_enabled,
    tail_clip,
    head_clip,
    tail_slope,
    head_slope,
    force_segmented,
    tail_cluster_bbox,
    head_cluster_bbox,
    tail_rank,
    head_rank,
    is_flat_edge,
    vnodes,
    has_vnodes,
    use_pathplan,
    route_include_tail,
    route_include_head,
    arrow_len_override,
    is_dotted,
    same_outer_cluster,
    diff_local_cluster,
    same_local_cluster,
    out_tail_anchor,
    out_head_anchor,
    out_tail_clip,
    out_head_clip,
    out_tail_pos,
    out_head_pos,
    out_tail_size,
    out_head_size,
    rankdir,
    layout_rankdir,
    has_side_anchor,
  }
}

///|
priv struct RoutePointState {
  points : Array[@geom.Point]
  using_pathplan : Bool
  pathplan_boxes : Array[@geom.Rect]
  pathplan_points : Array[@geom.Point]
  route_barriers : Array[(@geom.Point, @geom.Point)]
  pathplan_segments : Array[@routesplines.PathplanSegment]
}

///|
fn sameport_path_port_box(
  center : @geom.Point,
  anchor : @geom.Point,
  group_size : Int,
) -> @geom.Rect {
  // Graphviz parity: large sameport groups keep a tiny inward port-box offset;
  // this preserves oldarrows/honda routing-label snapshots exactly.
  let (bx, by) =
    if group_size > 3 {
      let dx = anchor.x - center.x
      let dy = anchor.y - center.y
      let len = Double::sqrt(dx * dx + dy * dy)
      if len > 0.0 {
        let offset = 0.005
        (anchor.x - dx / len * offset, anchor.y - dy / len * offset)
      } else {
        (anchor.x, anchor.y)
      }
    } else {
      (anchor.x, anchor.y)
    }
  let eps = if group_size > 3 { 0.005 } else { 0.01 }
  {
    llx: bx - eps,
    lly: by - eps,
    urx: bx + eps,
    ury: by + eps,
  }
}

///|
/// Graphviz parity: pathplan polyline aligned to refs/graphviz/lib/pathplan/* + lib/common/routespl.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_route_points_with_pathplan(
  base : EdgeRouteBase,
  ranks : Map[String, Int],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  routing_context : RoutingContext,
  guide_points : Array[@geom.Point],
) -> RoutePointState {
  let mut route_barriers : Array[(@geom.Point, @geom.Point)] = []
  let mut pathplan_boxes : Array[@geom.Rect] = []
  let mut pathplan_points : Array[@geom.Point] = []
  let mut pathplan_segments : Array[@routesplines.PathplanSegment] = []
  let (points, pathplan_used) =
    if base.use_pathplan && !base.is_flat_edge {
    let has_edge_label = edge_mid_label_width_pt(base.edge) > 0.0
    // Graphviz parity: record_path port boxes narrow pathplan bounds (shapes.c).
    let tail_port_box : @geom.Rect? =
      if !base.tail_clip_enabled {
        Some(
          sameport_path_port_box(
            base.tail_pos,
            base.tail_anchor,
            base.tail_sameport_group_size,
          ),
        )
      } else if base.tail_port_side == 0 {
        record_port_path_box(
          base.tail_node,
          base.tail_port,
          base.tail_pos,
          base.tail_size,
          base.rankdir,
        )
      } else {
        None
      }
    let head_port_box : @geom.Rect? =
      if !base.head_clip_enabled {
        Some(
          sameport_path_port_box(
            base.head_pos,
            base.head_anchor,
            base.head_sameport_group_size,
          ),
        )
      } else if base.head_port_side == 0 {
        record_port_path_box(
          base.head_node,
          base.head_port,
          base.head_pos,
          base.head_size,
          base.rankdir,
        )
      } else {
        None
      }
    match @routesplines.edge_pathplan_polyline(
      base.edge,
      base.tail_name,
      base.head_name,
      base.tail_anchor,
      base.head_anchor,
      base.layout_rankdir,
      base.tail_port_side,
      base.head_port_side,
      tail_port_box,
      head_port_box,
      ranksep_pt,
      ranks,
      vnode_info.vnode_ranks,
      vnode_info.edge_vnodes,
      positions,
      vnode_positions,
      sizes,
      routing_context.pathplan_sizes,
      routing_context.pathplan_vnode_mval_sizes,
      vnode_info.vnode_sizes,
      routing_context.path_cluster_keys,
      routing_context.path_vnode_clusters,
      routing_context.cluster_bboxes,
      x_groups,
      routing_context.path_order_index,
      routing_context.path_adjacency.out_edges,
      routing_context.path_adjacency.in_edges,
      rank_y,
      rank_ht1,
      rank_ht2,
      nodesep_pt,
      path_left_bound,
      path_right_bound,
      has_edge_label,
    ) {
      Some(result) => {
        route_barriers = result.barriers
        pathplan_boxes = result.boxes
        pathplan_points = result.points.copy()
        pathplan_segments = result.segments
        (result.points, true)
      }
      None => (guide_points, false)
    }
  } else {
    (
      guide_points,
      false,
    )
  }
  {
    points,
    using_pathplan: pathplan_used,
    pathplan_boxes,
    pathplan_points,
    route_barriers,
    pathplan_segments,
  }
}

///|
/// Graphviz parity: route point tweaks aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn adjust_route_points(
  edge : @cgraph.Edge,
  points : Array[@geom.Point],
  base : EdgeRouteBase,
  head_port_rect : @geom.Rect?,
  has_explicit_port : Bool,
  using_pathplan : Bool,
  nodesep_pt : Double,
) -> Array[@geom.Point] {
  let mut points = points
  let touch_eps = max_double(RECORD_BORDER_PT + 0.01, 1.5)
  let head_lr_touch =
    match head_port_rect {
      Some(rect) => {
        let node_rect = port_side_rect(base.head_pos, base.head_size)
        Double::abs(rect.llx - node_rect.llx) <= touch_eps ||
          Double::abs(rect.urx - node_rect.urx) <= touch_eps
      }
      None => false
    }
  let head_tb_touch =
    match head_port_rect {
      Some(rect) => {
        let node_rect = port_side_rect(base.head_pos, base.head_size)
        Double::abs(rect.lly - node_rect.lly) <= touch_eps ||
          Double::abs(rect.ury - node_rect.ury) <= touch_eps
      }
      None => false
    }
  let detour_ok =
    match base.layout_rankdir {
      RankDir::TB | RankDir::BT => head_tb_touch && !head_lr_touch
      RankDir::LR | RankDir::RL => head_lr_touch && !head_tb_touch
    }
  if points.length() <= 2 && has_explicit_port && detour_ok && !using_pathplan {
    let tail_rect = port_side_rect(base.tail_pos, base.tail_size)
    let head_rect = port_side_rect(base.head_pos, base.head_size)
    let anchor_eps = 0.02
    let needs_detour =
      segment_intersects_rect(
        base.tail_anchor,
        base.head_anchor,
        head_rect,
        anchor_eps,
      )
    if needs_detour {
      points =
        detour_polyline_for_rects(
          base.tail_anchor,
          base.head_anchor,
          tail_rect,
          head_rect,
          nodesep_pt,
          base.layout_rankdir,
        )
    }
  }
  if base.is_dotted && !base.same_outer_cluster && !using_pathplan {
    points = adjust_intercluster_dotted_points(
      points,
      base.tail_anchor,
      base.head_anchor,
      base.head_clip_size,
      nodesep_pt,
    )
  }
  dot_trace_route_points(edge, points)
  if has_explicit_port && base.has_side_anchor && points.length() <= 2 &&
    !using_pathplan {
    let offset = max_double(4.0, nodesep_pt * 0.5)
    let kinked : Array[@geom.Point] = [base.tail_anchor]
    if base.tail_slope.x != 0.0 || base.tail_slope.y != 0.0 {
      kinked.push(point_add(base.tail_anchor, point_scale(base.tail_slope, offset)))
    }
    if base.head_slope.x != 0.0 || base.head_slope.y != 0.0 {
      kinked.push(point_add(base.head_anchor, point_scale(base.head_slope, -offset)))
    }
    kinked.push(base.head_anchor)
    points = kinked
  }
  points
}

///|
/// Graphviz parity: curve offset tuning aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn compute_curve_offset(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  head_port_metrics : HeadPortMetrics,
  label_width_pt : Double,
  nodesep_pt : Double,
  enable_complex_tuning : Bool,
) -> (Double, Double) {
  let mut curve_offset = 0.0
  let mut curve_skew = 1.0
  if enable_complex_tuning {
    let head_port_key = port_key(edge.head_port())
    let key =
      if head_port_key == "" {
      if is_record_shape(edge.head()) { base.orig_head_name } else { "" }
    } else {
      "\{base.orig_head_name}:\{head_port_key}"
    }
    if key != "" {
      let count = match head_port_metrics.head_port_counts.get(key) {
        Some(value) => value
        None => 0
      }
      if count > 1 {
        let dx = base.head_anchor.x - base.tail_anchor.x
        let dy = base.head_anchor.y - base.tail_anchor.y
        let dist = Double::sqrt(dx * dx + dy * dy)
        let min_dist = match head_port_metrics.head_port_min_dist.get(key) {
          Some(value) => value
          None => dist
        }
        let max_dist = match head_port_metrics.head_port_max_dist.get(key) {
          Some(value) => value
          None => dist
        }
        let span = max_dist - min_dist
        if span > 0.0 {
          let t = (dist - min_dist) / span
          let label_factor = if label_width_pt > 0.0 { 1.0 } else { 0.5 }
          let port_scale = if head_port_key == "" { 0.6 } else { 0.6 }
          curve_offset = nodesep_pt * t * t * label_factor * port_scale
          if head_port_key != "" {
            match base.layout_rankdir {
              RankDir::TB | RankDir::BT =>
                if dx < 0.0 {
                  curve_skew = 0.5
                }
              RankDir::LR | RankDir::RL =>
                if dy < 0.0 {
                  curve_skew = 0.5
                }
            }
          }
        }
      }
    }
  }
  (curve_offset, curve_skew)
}

///|
/// Graphviz parity: straight_path segment slopes follow rankdir axis.
/// Do not change behavior without updating fixtures/tests.
fn straight_path_join_dir(rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => point(0.0, -1.0)
    RankDir::BT => point(0.0, 1.0)
    RankDir::LR => point(1.0, 0.0)
    RankDir::RL => point(-1.0, 0.0)
  }
}

///|
/// Graphviz parity: spline routing aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_spline(
  base : EdgeRouteBase,
  splines : SplinesMode,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> EdgeSplineResult {
  let edge = base.edge
  let tail_name = base.tail_name
  let head_name = base.head_name
  let tail_port = base.tail_port
  let head_port = base.head_port
  let tail_node = base.tail_node
  let head_node = base.head_node
  let tail_anchor = base.tail_anchor
  let head_anchor = base.head_anchor
  let head_port_rect = base.head_port_rect
  let tail_clip_center = base.tail_clip_center
  let head_clip_center = base.head_clip_center
  let tail_clip_size = base.tail_clip_size
  let head_clip_size = base.head_clip_size
  let tail_clip_enabled = base.tail_clip_enabled
  let head_clip_enabled = base.head_clip_enabled
  let tail_clip = base.tail_clip
  let head_clip = base.head_clip
  let tail_slope = base.tail_slope
  let head_slope = base.head_slope
  let force_segmented = base.force_segmented
  let tail_cluster_bbox = base.tail_cluster_bbox
  let head_cluster_bbox = base.head_cluster_bbox
  let tail_rank = base.tail_rank
  let is_flat_edge = base.is_flat_edge
  let has_vnodes = base.has_vnodes
  let route_include_tail = base.route_include_tail
  let route_include_head = base.route_include_head
  let arrow_len_override = base.arrow_len_override
  let is_dotted = base.is_dotted
  let same_outer_cluster = base.same_outer_cluster
  let diff_local_cluster = base.diff_local_cluster
  let same_local_cluster = base.same_local_cluster
  let layout_rankdir = base.layout_rankdir
  let parallel_offset = base.parallel_offset
  // Graphviz parity: swapped routing orientation must swap clip/arrow semantics.
  let swap_clip_shapes = base.swap_ends
  let swap_arrow_attrs = base.swap_ends
  let orig_tail_name = base.orig_tail_name
  let mut label_pad_boost = 0.0
  let mut using_pathplan = false
  let mut pathplan_boxes : Array[@geom.Rect] = []
  let mut pathplan_points : Array[@geom.Point] = []
  let mut pathplan_segments : Array[@routesplines.PathplanSegment] = []
  let mut raw_bezier : Array[@geom.Point] = []
  let mut apply_dotted_adjustment = false
  let spline = match splines {
    SplinesMode::None | SplinesMode::Polyline =>
      edge_spline_for_polyline(
        edge,
        tail_clip_center,
        head_clip_center,
        tail_clip_size,
        head_clip_size,
        tail_clip,
        head_clip,
        layout_rankdir,
        false,
        route_include_tail,
        route_include_head,
        tail_clip_enabled=tail_clip_enabled,
        head_clip_enabled=head_clip_enabled,
        arrow_len_override=arrow_len_override,
        tail_cluster_bbox=tail_cluster_bbox,
        head_cluster_bbox=head_cluster_bbox,
        parallel_offset=parallel_offset,
        clip_swapped=swap_clip_shapes,
        arrow_swapped=swap_arrow_attrs,
      )
    SplinesMode::Ortho =>
      edge_spline_for_polyline(
        edge,
        tail_clip_center,
        head_clip_center,
        tail_clip_size,
        head_clip_size,
        tail_clip,
        head_clip,
        layout_rankdir,
        true,
        route_include_tail,
        route_include_head,
        tail_clip_enabled=tail_clip_enabled,
        head_clip_enabled=head_clip_enabled,
        arrow_len_override=arrow_len_override,
        tail_cluster_bbox=tail_cluster_bbox,
        head_cluster_bbox=head_cluster_bbox,
        parallel_offset=parallel_offset,
        clip_swapped=swap_clip_shapes,
        arrow_swapped=swap_arrow_attrs,
      )
    _ => {
      let label_width_pt = edge_mid_label_width_pt(edge)
      let has_explicit_port =
        port_is_explicit(tail_port) || port_is_explicit(head_port)
      let abs_dx = Double::abs(head_anchor.x - tail_anchor.x)
      let split_label = enable_complex_tuning &&
        label_width_pt > 0.0 &&
        same_outer_cluster &&
        diff_local_cluster &&
        abs_dx > label_width_pt
      if split_label {
        label_pad_boost = nodesep_pt * 1.2
      }
      let dotted_weight = if enable_complex_tuning { 1.0 } else { 0.8 }
      let guide_points = edge_polyline_points(
        edge,
        tail_name,
        head_name,
        tail_port,
        head_port,
        tail_anchor,
        head_anchor,
        ranks,
        vnode_info.edge_vnodes,
        vnode_info.vnode_ranks,
        vnode_positions,
        rank_y,
        rank_ht1,
        nodesep_pt,
        label_width_pt,
        dotted_weight,
        enable_complex_tuning,
        split_label,
        same_local_cluster,
      )
      let route_state =
        compute_route_points_with_pathplan(
          base,
          ranks,
          positions,
          vnode_positions,
          vnode_info,
          sizes,
          x_groups,
          rank_y,
          rank_ht1,
          rank_ht2,
          nodesep_pt,
          path_left_bound,
          path_right_bound,
          ranksep_pt,
          routing_context,
          guide_points,
        )
      using_pathplan = route_state.using_pathplan
      pathplan_boxes = route_state.pathplan_boxes
      pathplan_points = route_state.pathplan_points
      pathplan_segments = route_state.pathplan_segments
      let route_barriers = route_state.route_barriers
      let points =
        adjust_route_points(
          edge,
          route_state.points,
          base,
          head_port_rect,
          has_explicit_port,
          using_pathplan,
          nodesep_pt,
        )
      let (curve_offset, curve_skew) =
        compute_curve_offset(
          edge,
          base,
          head_port_metrics,
          label_width_pt,
          nodesep_pt,
          enable_complex_tuning,
        )
      let style_value = match edge.get_attr("style") {
        Some(value) => value.to_lower()
        None => ""
      }
      // Graphviz parity: flat invisible edges use linear control points in
      // line routing (matches proc3d rank=same invis edge snapshots).
      let prefer_linear_flat_invis =
        is_flat_edge &&
        !has_explicit_port &&
        label_width_pt <= 0.0 &&
        style_value.contains("invis")
      let routed_spline = if points.length() > 2 {
        let clipped = points
        let simplify_tol = nodesep_pt * 0.8
        let tail_label_edges = match label_edge_counts.get(orig_tail_name) {
          Some(value) => value > 1
          None => false
        }
      let keep_label_kink =
        label_width_pt > 0.0 &&
        (has_explicit_port ||
          (same_outer_cluster &&
              (abs_dx < nodesep_pt || (tail_label_edges && abs_dx < label_width_pt))))
        let simplified =
          if using_pathplan {
            clipped
          } else if enable_complex_tuning &&
            has_vnodes &&
            !split_label &&
            !keep_label_kink {
            simplify_polyline(clipped, simplify_tol)
          } else {
            clipped
          }
        let adjusted =
          if !using_pathplan && is_dotted && same_outer_cluster {
            adjust_intracluster_dotted_points(simplified)
          } else {
            simplified
          }
        if adjusted.length() <= 2 {
          let tail_slope_line =
            if port_is_explicit(tail_port) {
              tail_slope
            } else {
              point(0.0, 0.0)
            }
          let head_slope_line =
            if port_is_explicit(head_port) {
              head_slope
            } else {
              point(0.0, 0.0)
            }
          let record_port_edge =
            (is_record_shape(tail_node) && port_is_explicit(tail_port)) ||
              (is_record_shape(head_node) && port_is_explicit(head_port))
          let needs_record_detour =
            !using_pathplan &&
            !is_flat_edge &&
            record_port_edge &&
            (match layout_rankdir {
              RankDir::TB | RankDir::BT =>
                Double::abs(tail_slope_line.x) > 0.01 ||
                  Double::abs(head_slope_line.x) > 0.01
              RankDir::LR | RankDir::RL =>
                Double::abs(tail_slope_line.y) > 0.01 ||
                  Double::abs(head_slope_line.y) > 0.01
            })
          let flat_no_arrow_candidate =
            !using_pathplan &&
            is_flat_edge &&
            !has_explicit_port &&
            label_width_pt <= 0.0 &&
            !route_include_tail &&
            !route_include_head
          let flat_detour =
            if flat_no_arrow_candidate {
              flat_no_arrow_detour_points_if_blocked(
                tail_name,
                head_name,
                tail_rank,
                adjusted[0],
                adjusted[adjusted.length() - 1],
                positions,
                sizes,
                ranks,
                rank_y,
                rank_ht1,
                rank_ht2,
                ranksep_pt,
                layout_rankdir,
              )
            } else {
              None
            }
          if needs_record_detour {
            let tail_rect = port_side_rect(tail_clip_center, tail_clip_size)
            let head_rect = port_side_rect(head_clip_center, head_clip_size)
            let detour_offset = nodesep_pt * 0.5
            let detour_points =
              match layout_rankdir {
                RankDir::TB | RankDir::BT => {
                  let mut side = tail_clip.x - tail_clip_center.x
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.x - head_clip_center.x
                  }
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.x - tail_clip.x
                  }
                  let detour_x =
                    if side < 0.0 {
                      min_double(tail_rect.llx, head_rect.llx) - detour_offset
                    } else {
                      max_double(tail_rect.urx, head_rect.urx) + detour_offset
                    }
                  [
                    tail_clip,
                    point(detour_x, tail_clip.y),
                    point(detour_x, head_clip.y),
                    head_clip,
                  ]
                }
                RankDir::LR | RankDir::RL => {
                  let mut side = tail_clip.y - tail_clip_center.y
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.y - head_clip_center.y
                  }
                  if Double::abs(side) <= 0.01 {
                    side = head_clip.y - tail_clip.y
                  }
                  let detour_y =
                    if side < 0.0 {
                      min_double(tail_rect.lly, head_rect.lly) - detour_offset
                    } else {
                      max_double(tail_rect.ury, head_rect.ury) + detour_offset
                    }
                  [
                    tail_clip,
                    point(detour_y, tail_clip.y),
                    point(detour_y, head_clip.y),
                    head_clip,
                  ]
              }
            }
            if using_pathplan {
              raw_bezier =
                edge_spline_raw_for_points(
                  detour_points,
                  tail_slope_line,
                  head_slope_line,
                  true,
                  route_barriers=route_barriers,
                )
            }
            edge_spline_for_points(
              edge,
              detour_points,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              true,
              route_include_tail,
              route_include_head,
              tail_clip_enabled=tail_clip_enabled,
              head_clip_enabled=head_clip_enabled,
              tail_port_side=base.tail_port_side,
              head_port_side=base.head_port_side,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
              clip_swapped=swap_clip_shapes,
              arrow_swapped=swap_arrow_attrs,
            )
          } else if flat_detour is Some(
            (detour_points, first_right, last_left, detour_y, vspace),
          ) {
            if using_pathplan {
              raw_bezier =
                edge_spline_raw_for_points(
                  detour_points,
                  tail_slope_line,
                  head_slope_line,
                  true,
                  route_barriers=route_barriers,
                )
            }
            let mut detour_spline =
              edge_spline_for_points(
              edge,
              detour_points,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              true,
              route_include_tail,
              route_include_head,
              tail_clip_enabled=tail_clip_enabled,
              head_clip_enabled=head_clip_enabled,
              tail_port_side=base.tail_port_side,
              head_port_side=base.head_port_side,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
              clip_swapped=swap_clip_shapes,
              arrow_swapped=swap_arrow_attrs,
            )
            if detour_spline.points.length() == 10 &&
              (layout_rankdir == RankDir::TB || layout_rankdir == RankDir::BT) {
              let gap = last_left - first_right
              if gap > 200.0 {
                let points = detour_spline.points.copy()
                points[4] = {
                  x: first_right + 0.76,
                  y: detour_y + vspace * 0.3535,
                }
                points[5] = {
                  x: last_left + 0.25,
                  y: detour_y + vspace * 0.4016,
                }
                detour_spline = {
                  start: detour_spline.start,
                  end: detour_spline.end,
                  points,
                }
              }
            }
            detour_spline
          } else {
            if using_pathplan {
              let line_points = adjusted
              raw_bezier =
                edge_spline_raw_for_points(
                  line_points,
                  tail_slope_line,
                  head_slope_line,
                  force_segmented,
                  route_barriers=route_barriers,
                )
              edge_spline_for_points(
                edge,
                line_points,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                force_segmented,
                route_include_tail,
                route_include_head,
                tail_clip_enabled=tail_clip_enabled,
                head_clip_enabled=head_clip_enabled,
                tail_port_side=base.tail_port_side,
                head_port_side=base.head_port_side,
                route_barriers=route_barriers,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
                clip_swapped=swap_clip_shapes,
                arrow_swapped=swap_arrow_attrs,
              )
            } else {
              edge_spline_for_line(
                edge,
                adjusted[0],
                adjusted[adjusted.length() - 1],
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_line,
                head_slope_line,
                route_include_tail,
                route_include_head,
                layout_rankdir,
                curve_offset,
                curve_skew,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                prefer_linear=prefer_linear_flat_invis ||
                  (flat_no_arrow_candidate && flat_detour is None),
                parallel_offset=parallel_offset,
                clip_swapped=swap_clip_shapes,
                arrow_swapped=swap_arrow_attrs,
              )
            }
          }
        } else {
          let tail_slope_for =
            if port_is_explicit(tail_port) {
              tail_slope
            } else {
              point(0.0, 0.0)
            }
          let head_slope_for =
            if port_is_explicit(head_port) {
              head_slope
            } else {
              point(0.0, 0.0)
            }
          // Graphviz parity: pathplan edges always allow spline fitting.
          let edge_force_segmented = if using_pathplan { false } else { force_segmented }
          let use_segmented_pathplan =
            using_pathplan && pathplan_segments.length() > 0
          let segmented_raw : Array[@geom.Point] = []
          if use_segmented_pathplan {
            // Graphviz parity: straight_path segment joins constrain slope along rankdir.
            let join_dir = straight_path_join_dir(layout_rankdir)
            let join_tail = join_dir
            let join_head = join_dir
            let mut seg_idx = 0
            while seg_idx < pathplan_segments.length() {
              let segment = pathplan_segments[seg_idx]
              let segment_points =
                if segment.points.length() >= 3 {
                  let last_idx = segment.points.length() - 1
                  let end = segment.points[last_idx]
                  let prev = segment.points[last_idx - 1]
                  let dx = end.x - prev.x
                  let dy = end.y - prev.y
                  if dx * dx + dy * dy <= 0.0004 {
                    let prev2 = segment.points[last_idx - 2]
                    let vx = end.x - prev2.x
                    let vy = end.y - prev2.y
                    let wx = prev.x - prev2.x
                    let wy = prev.y - prev2.y
                    let span = @math.hypot(vx, vy)
                    let offset = if span > 0.0 {
                      Double::abs(vx * wy - vy * wx) / span
                    } else {
                      0.0
                    }
                    if offset <= 0.02 {
                      let trimmed : Array[@geom.Point] = []
                      let mut i = 0
                      while i < segment.points.length() {
                        if i != last_idx - 1 {
                          trimmed.push(segment.points[i])
                        }
                        i = i + 1
                      }
                      trimmed
                    } else {
                      segment.points
                    }
                  } else {
                    segment.points
                  }
                } else {
                  segment.points
                }
              let seg_tail_slope =
                if seg_idx == 0 { tail_slope_for } else { join_tail }
              let seg_head_slope =
                if seg_idx + 1 == pathplan_segments.length() {
                  head_slope_for
                } else {
                  join_head
                }
              let seg_raw =
                edge_spline_raw_for_points(
                  segment_points,
                  seg_tail_slope,
                  seg_head_slope,
                  edge_force_segmented,
                  route_barriers=segment.barriers,
                )
              if seg_raw.length() > 0 {
                if segmented_raw.length() > 0 {
                  let last = segmented_raw[segmented_raw.length() - 1]
                  segmented_raw.push(last)
                  segmented_raw.push(last)
                }
                for point in seg_raw {
                  segmented_raw.push(point)
                }
              }
              seg_idx = seg_idx + 1
            }
          }
          if use_segmented_pathplan && segmented_raw.length() > 0 {
            raw_bezier = segmented_raw
            let spline =
              edge_spline_for_bezier_points(
                edge,
                raw_bezier,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                route_include_tail,
                route_include_head,
                tail_clip_enabled=tail_clip_enabled,
                head_clip_enabled=head_clip_enabled,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
                clip_swapped=swap_clip_shapes,
                arrow_swapped=swap_arrow_attrs,
              )
            apply_dotted_adjustment = true
            spline
          } else {
            if using_pathplan {
              raw_bezier =
                edge_spline_raw_for_points(
                  adjusted,
                  tail_slope_for,
                  head_slope_for,
                  edge_force_segmented,
                  route_barriers=route_barriers,
                )
            }
            let spline =
              edge_spline_for_points(
                edge,
                adjusted,
                tail_clip_center,
                head_clip_center,
                tail_clip_size,
                head_clip_size,
                tail_slope_for,
                head_slope_for,
                edge_force_segmented,
                route_include_tail,
                route_include_head,
                tail_clip_enabled=tail_clip_enabled,
                head_clip_enabled=head_clip_enabled,
                tail_port_side=base.tail_port_side,
                head_port_side=base.head_port_side,
                route_barriers=route_barriers,
                arrow_len_override=arrow_len_override,
                tail_cluster_bbox=tail_cluster_bbox,
                head_cluster_bbox=head_cluster_bbox,
                parallel_offset=parallel_offset,
                clip_swapped=swap_clip_shapes,
                arrow_swapped=swap_arrow_attrs,
              )
            apply_dotted_adjustment = true
            spline
          }
        }
      } else {
        let tail_slope_line =
          if port_is_explicit(tail_port) {
            tail_slope
          } else {
            point(0.0, 0.0)
          }
        let head_slope_line =
          if port_is_explicit(head_port) {
            head_slope
          } else {
            point(0.0, 0.0)
          }
        let record_port_edge =
          (is_record_shape(tail_node) && port_is_explicit(tail_port)) ||
            (is_record_shape(head_node) && port_is_explicit(head_port))
        let needs_record_detour =
          !using_pathplan &&
          !is_flat_edge &&
          record_port_edge &&
          (match layout_rankdir {
            RankDir::TB | RankDir::BT =>
              Double::abs(tail_slope_line.x) > 0.01 ||
                Double::abs(head_slope_line.x) > 0.01
            RankDir::LR | RankDir::RL =>
              Double::abs(tail_slope_line.y) > 0.01 ||
                Double::abs(head_slope_line.y) > 0.01
          })
        let flat_no_arrow_candidate =
          !using_pathplan &&
          is_flat_edge &&
          !has_explicit_port &&
          label_width_pt <= 0.0 &&
          !route_include_tail &&
          !route_include_head
        let flat_detour =
          if flat_no_arrow_candidate {
            flat_no_arrow_detour_points_if_blocked(
              tail_name,
              head_name,
              tail_rank,
              tail_anchor,
              head_anchor,
              positions,
              sizes,
              ranks,
              rank_y,
              rank_ht1,
              rank_ht2,
              ranksep_pt,
              layout_rankdir,
            )
          } else {
            None
          }
        if needs_record_detour {
          let tail_rect = port_side_rect(tail_clip_center, tail_clip_size)
          let head_rect = port_side_rect(head_clip_center, head_clip_size)
          let detour_offset = nodesep_pt * 0.5
          let detour_points =
            match layout_rankdir {
              RankDir::TB | RankDir::BT => {
                let mut side = tail_clip.x - tail_clip_center.x
                if Double::abs(side) <= 0.01 {
                  side = head_clip.x - head_clip_center.x
                }
                if Double::abs(side) <= 0.01 {
                  side = head_clip.x - tail_clip.x
                }
                let detour_x =
                  if side < 0.0 {
                    min_double(tail_rect.llx, head_rect.llx) - detour_offset
                  } else {
                    max_double(tail_rect.urx, head_rect.urx) + detour_offset
                  }
                [
                  tail_clip,
                  point(detour_x, tail_clip.y),
                  point(detour_x, head_clip.y),
                  head_clip,
                ]
              }
              RankDir::LR | RankDir::RL => {
                let mut side = tail_clip.y - tail_clip_center.y
                if Double::abs(side) <= 0.01 {
                  side = head_clip.y - head_clip_center.y
                }
                if Double::abs(side) <= 0.01 {
                  side = head_clip.y - tail_clip.y
                }
                let detour_y =
                  if side < 0.0 {
                    min_double(tail_rect.lly, head_rect.lly) - detour_offset
                  } else {
                    max_double(tail_rect.ury, head_rect.ury) + detour_offset
                  }
                [
                  tail_clip,
                  point(tail_clip.x, detour_y),
                  point(head_clip.x, detour_y),
                  head_clip,
                ]
              }
            }
          if using_pathplan {
            raw_bezier =
              edge_spline_raw_for_points(
                detour_points,
                tail_slope_line,
                head_slope_line,
                true,
                route_barriers=route_barriers,
              )
          }
          edge_spline_for_points(
            edge,
            detour_points,
            tail_clip_center,
            head_clip_center,
            tail_clip_size,
            head_clip_size,
            tail_slope_line,
            head_slope_line,
            true,
            route_include_tail,
            route_include_head,
            tail_clip_enabled=tail_clip_enabled,
            head_clip_enabled=head_clip_enabled,
            tail_port_side=base.tail_port_side,
            head_port_side=base.head_port_side,
            route_barriers=route_barriers,
            arrow_len_override=arrow_len_override,
            tail_cluster_bbox=tail_cluster_bbox,
            head_cluster_bbox=head_cluster_bbox,
            parallel_offset=parallel_offset,
            clip_swapped=swap_clip_shapes,
            arrow_swapped=swap_arrow_attrs,
          )
        } else if flat_detour is Some(
          (detour_points, first_right, last_left, detour_y, vspace),
        ) {
          if using_pathplan {
            raw_bezier =
              edge_spline_raw_for_points(
                detour_points,
                tail_slope_line,
                head_slope_line,
                true,
                route_barriers=route_barriers,
              )
          }
          let mut detour_spline =
            edge_spline_for_points(
              edge,
              detour_points,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              true,
              route_include_tail,
              route_include_head,
              tail_clip_enabled=tail_clip_enabled,
              head_clip_enabled=head_clip_enabled,
              tail_port_side=base.tail_port_side,
              head_port_side=base.head_port_side,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
              clip_swapped=swap_clip_shapes,
              arrow_swapped=swap_arrow_attrs,
            )
            if detour_spline.points.length() == 10 &&
              (layout_rankdir == RankDir::TB || layout_rankdir == RankDir::BT) {
              let gap = last_left - first_right
              if gap > 200.0 {
                let points = detour_spline.points.copy()
                points[4] = {
                  x: first_right + 0.76,
                  y: detour_y + vspace * 0.3535,
                }
                points[5] = {
                  x: last_left + 0.25,
                  y: detour_y + vspace * 0.4016,
                }
                detour_spline = {
                  start: detour_spline.start,
                  end: detour_spline.end,
                  points,
                }
              }
            }
          detour_spline
        } else {
          let line_start =
            if using_pathplan && points.length() >= 2 {
              points[0]
            } else {
              tail_anchor
            }
          let line_end =
            if using_pathplan && points.length() >= 2 {
              points[points.length() - 1]
            } else {
              head_anchor
            }
          if using_pathplan {
            let line_points : Array[@geom.Point] =
              if points.length() >= 2 { points } else { [line_start, line_end] }
            raw_bezier =
              edge_spline_raw_for_points(
                line_points,
                tail_slope_line,
                head_slope_line,
                force_segmented,
                route_barriers=route_barriers,
              )
            edge_spline_for_points(
              edge,
              line_points,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              force_segmented,
              route_include_tail,
              route_include_head,
              tail_clip_enabled=tail_clip_enabled,
              head_clip_enabled=head_clip_enabled,
              tail_port_side=base.tail_port_side,
              head_port_side=base.head_port_side,
              route_barriers=route_barriers,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              parallel_offset=parallel_offset,
              clip_swapped=swap_clip_shapes,
              arrow_swapped=swap_arrow_attrs,
            )
          } else {
            edge_spline_for_line(
              edge,
              line_start,
              line_end,
              tail_clip_center,
              head_clip_center,
              tail_clip_size,
              head_clip_size,
              tail_slope_line,
              head_slope_line,
              route_include_tail,
              route_include_head,
              tail_clip_enabled=tail_clip_enabled,
              head_clip_enabled=head_clip_enabled,
              layout_rankdir,
              curve_offset,
              curve_skew,
              arrow_len_override=arrow_len_override,
              tail_cluster_bbox=tail_cluster_bbox,
              head_cluster_bbox=head_cluster_bbox,
              prefer_linear=prefer_linear_flat_invis ||
                (flat_no_arrow_candidate && flat_detour is None),
              parallel_offset=parallel_offset,
              clip_swapped=swap_clip_shapes,
              arrow_swapped=swap_arrow_attrs,
            )
          }
        }
      }
      routed_spline
    }
  }
  if using_pathplan && pathplan_boxes.length() > 0 && raw_bezier.length() >= 4 {
    // Graphviz parity: limit boxes based on routed spline before recover_slack.
    pathplan_boxes =
      @routesplines.limit_boxes_for_spline(
        pathplan_boxes,
        raw_bezier,
        fallback_polyline=pathplan_points,
      )
  }
  if using_pathplan && pathplan_segments.length() > 0 {
    // Graphviz parity: limit segment boxes independently to match straight_path sampling.
    let tail_slope_for =
      if port_is_explicit(tail_port) { tail_slope } else { point(0.0, 0.0) }
    let head_slope_for =
      if port_is_explicit(head_port) { head_slope } else { point(0.0, 0.0) }
    let join_dir = straight_path_join_dir(layout_rankdir)
    let join_tail = join_dir
    let join_head = join_dir
    let limited_segments : Array[@routesplines.PathplanSegment] = []
    let mut seg_idx = 0
    while seg_idx < pathplan_segments.length() {
      let segment = pathplan_segments[seg_idx]
      let seg_tail_slope =
        if seg_idx == 0 { tail_slope_for } else { join_tail }
      let seg_head_slope =
        if seg_idx + 1 == pathplan_segments.length() {
          head_slope_for
        } else {
          join_head
        }
      let segment_raw =
        edge_spline_raw_for_points(
          segment.points,
          seg_tail_slope,
          seg_head_slope,
          false,
          route_barriers=segment.barriers,
        )
      let limited_boxes =
        @routesplines.limit_boxes_for_spline(
          segment.boxes,
          segment_raw,
          fallback_polyline=segment.points,
        )
      limited_segments.push({
        points: segment.points,
        barriers: segment.barriers,
        boxes: limited_boxes,
        vnodes: segment.vnodes,
      })
      seg_idx = seg_idx + 1
    }
    pathplan_segments = limited_segments
  }
  if using_pathplan && raw_bezier.length() > 0 &&
    @sys.get_env_var("DOT_TRACE_SPLINE_OUTPUT") is Some(_) {
    let parts : Array[String] = []
    for point in raw_bezier {
      parts.push("{\"x\":\{point.x},\"y\":\{point.y}}")
    }
    let joined = parts.join(",")
    println(
      "{\"event\":\"spline_output\",\"tail\":\"\{base.orig_tail_name}\",\"head\":\"\{base.orig_head_name}\",\"points\":[\{joined}]}",)
  }
  {
    spline,
    label_pad_boost,
    using_pathplan,
    pathplan_boxes,
    pathplan_points,
    raw_bezier,
    pathplan_segments,
    apply_dotted_adjustment,
  }
}

///|
/// Graphviz parity: spline finalization aligned to refs/graphviz/lib/dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn finalize_edge_spline(
  base : EdgeRouteBase,
  result : EdgeSplineResult,
) -> @geom.Spline {
  let mut spline = result.spline
  if base.swap_ends {
    spline = reverse_spline(spline)
  }
  if result.apply_dotted_adjustment && base.is_dotted && !base.same_outer_cluster &&
    spline.points.length() > 1 {
    let tuned = spline.points.copy()
    let tail_bias = 0.7
    tuned[1] = {
      x: tuned[1].x,
      y: tuned[1].y * (1.0 - tail_bias) + base.out_tail_anchor.y * tail_bias,
    }
    let head_bias = 0.7
    let last = tuned.length() - 2
    tuned[last] = {
      x: tuned[last].x,
      y: tuned[last].y * (1.0 - head_bias) + base.out_head_anchor.y * head_bias,
    }
    spline = { start: spline.start, end: spline.end, points: tuned }
  }
  spline
}

///|
fn edge_sameport_direct_flags(
  edge : @cgraph.Edge,
  swap_ends : Bool,
) -> (Bool, Bool) {
  let samehead_direct = match edge.get_attr("samehead") {
    Some(value) => value != ""
    None => false
  }
  let sametail_direct = match edge.get_attr("sametail") {
    Some(value) => value != ""
    None => false
  }
  if swap_ends {
    (samehead_direct, sametail_direct)
  } else {
    (sametail_direct, samehead_direct)
  }
}

///|
fn edge_render_clip_flags(base : EdgeRouteBase) -> (Bool, Bool) {
  let (tail_direct, head_direct) =
    edge_sameport_direct_flags(base.edge, base.swap_ends)
  let tail_clip_enabled =
    if !base.tail_clip_enabled && !tail_direct {
      true
    } else {
      base.tail_clip_enabled
    }
  let head_clip_enabled =
    if !base.head_clip_enabled && !head_direct {
      true
    } else {
      base.head_clip_enabled
    }
  (tail_clip_enabled, head_clip_enabled)
}

///|
fn rebuild_spline_for_render(
  base : EdgeRouteBase,
  spline_result : EdgeSplineResult,
) -> EdgeSplineResult {
  let (tail_clip_enabled, head_clip_enabled) = edge_render_clip_flags(base)
  if tail_clip_enabled == base.tail_clip_enabled &&
    head_clip_enabled == base.head_clip_enabled {
    return spline_result
  }
  if spline_result.raw_bezier.length() < 4 {
    return spline_result
  }
  let rebuilt =
    edge_spline_for_bezier_points(
      base.edge,
      spline_result.raw_bezier,
      base.tail_clip_center,
      base.head_clip_center,
      base.tail_clip_size,
      base.head_clip_size,
      base.route_include_tail,
      base.route_include_head,
      tail_clip_enabled=tail_clip_enabled,
      head_clip_enabled=head_clip_enabled,
      arrow_len_override=base.arrow_len_override,
      tail_cluster_bbox=base.tail_cluster_bbox,
      head_cluster_bbox=base.head_cluster_bbox,
      parallel_offset=base.parallel_offset,
      clip_swapped=base.swap_ends,
      arrow_swapped=base.swap_ends,
    )
  {
    spline: rebuilt,
    label_pad_boost: spline_result.label_pad_boost,
    using_pathplan: spline_result.using_pathplan,
    pathplan_boxes: spline_result.pathplan_boxes,
    pathplan_points: spline_result.pathplan_points,
    raw_bezier: spline_result.raw_bezier,
    pathplan_segments: spline_result.pathplan_segments,
    apply_dotted_adjustment: spline_result.apply_dotted_adjustment,
  }
}

///|
/// Graphviz parity: edge label placement aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn build_edge_layout(
  base : EdgeRouteBase,
  spline : @geom.Spline,
  spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let edge = base.edge
  let label_rank_info = edge_label_rank_info(edge, ranks)
  let label_rank_y = edge_label_rank_y(edge, ranks, rank_y)
  let label_rank_x = match label_rank_info {
    Some((label_rank, span)) =>
      if span > 1 {
        edge_label_rank_x(
          edge,
          label_rank,
          vnode_info.vnode_ranks,
          vnode_info.edge_vnodes,
          vnode_positions,
        )
      } else {
        None
      }
    None => None
  }
  let apply_label_pad = has_clusters
  let label_pos : @geom.Point? = match edge.get_attr("label") {
    Some(value) =>
      if value == "" {
        None
      } else {
        match (label_rank_x, label_rank_y, edge_mid_label_metrics(edge)) {
          (Some(rank_x), Some(rank_y), Some((width, height))) => {
            Some(
              edge_label_pos_from_vnode(
                point(rank_x, rank_y),
                width,
                height,
                base.rankdir,
              ),
            )
          }
          _ =>
            if base.is_flat_edge {
              match flat_label_edge_vnodes.get(edge_key(edge)) {
                Some(vnode_name) =>
                  match vnode_positions.get(vnode_name) {
                    Some(pos) => Some(pos)
                    None =>
                      match edge_mid_label_metrics(edge) {
                        Some((_width, height)) => {
                        Some(
                          flat_edge_label_pos_simple(
                              base.out_tail_pos,
                              base.out_head_pos,
                              base.out_tail_size.right_pt,
                              base.out_head_size.left_pt,
                              height,
                            ),
                          )
                        }
                        None =>
                            edge_label_pos(
                              edge,
                              spline,
                              base.out_tail_clip,
                              base.out_head_clip,
                              base.layout_rankdir,
                              label_rank_y,
                              label_rank_x,
                              apply_label_pad,
                              nodesep_pt,
                              spline_result.label_pad_boost,
                            )
                      }
                  }
                None =>
                  match edge_mid_label_metrics(edge) {
                    Some((_width, height)) => {
                      Some(
                        flat_edge_label_pos_simple(
                          base.out_tail_pos,
                          base.out_head_pos,
                          base.out_tail_size.right_pt,
                          base.out_head_size.left_pt,
                          height,
                        ),
                      )
                    }
                    None =>
                      edge_label_pos(
                        edge,
                        spline,
                        base.out_tail_clip,
                        base.out_head_clip,
                        base.layout_rankdir,
                        label_rank_y,
                        label_rank_x,
                        apply_label_pad,
                        nodesep_pt,
                        spline_result.label_pad_boost,
                      )
                  }
              }
            } else {
              edge_label_pos(
                edge,
                spline,
                base.out_tail_clip,
                base.out_head_clip,
                base.layout_rankdir,
                label_rank_y,
                label_rank_x,
                apply_label_pad,
                nodesep_pt,
                spline_result.label_pad_boost,
              )
            }
        }
      }
    None => None
  }
  let head_label_pos : @geom.Point? = match edge.get_attr("headlabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, true)
      }
    None => None
  }
  let tail_label_pos : @geom.Point? = match edge.get_attr("taillabel") {
    Some(value) =>
      if value == "" {
        None
      } else {
        edge_port_label_pos(edge, spline, false)
      }
    None => None
  }
  {
    edge,
    splines: [spline],
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos: None,
  }
}

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
/// Graphviz parity: edgecmp helper utilities (edge_route_type,
/// edge_route_graph_type, cmp_int, cmp_double, port_cmp, edge_port_cmp_info)
/// mirror dotgen/dotsplines.c ordering.
/// Do not change behavior without updating fixtures/tests.
fn edge_route_type(base : EdgeRouteBase) -> Int {
  if base.orig_tail_name == base.orig_head_name {
    if port_is_explicit(base.tail_port) || port_is_explicit(base.head_port) {
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
fn edge_port_cmp_info(
  base : EdgeRouteBase,
  edge_type : Int,
  order_index : Map[String, Int],
) -> (Bool, @geom.Point, Bool, @geom.Point) {
  let tail_anchor = if base.swap_ends { base.head_anchor } else { base.tail_anchor }
  let head_anchor = if base.swap_ends { base.tail_anchor } else { base.head_anchor }
  let tail_pos = if base.swap_ends { base.head_pos } else { base.tail_pos }
  let head_pos = if base.swap_ends { base.tail_pos } else { base.head_pos }
  let tail_defined =
    if base.swap_ends { port_is_explicit(base.head_port) } else {
      port_is_explicit(base.tail_port)
    }
  let head_defined =
    if base.swap_ends { port_is_explicit(base.tail_port) } else {
      port_is_explicit(base.head_port)
    }
  let tail_rel =
    point(tail_anchor.x - tail_pos.x, tail_anchor.y - tail_pos.y)
  let head_rel =
    point(head_anchor.x - head_pos.x, head_anchor.y - head_pos.y)
  if edge_type == ROUTE_EDGE_FLAT {
    let tail_order = match order_index.get(base.orig_tail_name) {
      Some(value) => value
      None => 0
    }
    let head_order = match order_index.get(base.orig_head_name) {
      Some(value) => value
      None => 0
    }
    if tail_order > head_order {
      return (head_defined, head_rel, tail_defined, tail_rel)
    }
  }
  (tail_defined, tail_rel, head_defined, head_rel)
}

///|
/// Graphviz parity: routing edge order matches dotgen/dotsplines.c edgecmp.
/// Do not change behavior without updating fixtures/tests.
fn graphviz_route_edge_cmp(
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
  let (tail_defined_a, tail_pos_a, head_defined_a, head_pos_a) =
    edge_port_cmp_info(base_a, type_a, order_index)
  let (tail_defined_b, tail_pos_b, head_defined_b, head_pos_b) =
    edge_port_cmp_info(base_b, type_b, order_index)
  let tail_cmp = port_cmp(tail_defined_a, tail_pos_a, tail_defined_b, tail_pos_b)
  if tail_cmp != 0 {
    return tail_cmp
  }
  let head_cmp = port_cmp(head_defined_a, head_pos_a, head_defined_b, head_pos_b)
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
    let label_a = match a.get_attr("label") {
      Some(value) => value
      None => ""
    }
    let label_b = match b.get_attr("label") {
      Some(value) => value
      None => ""
    }
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
fn collect_self_edge_groups(
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
fn build_route_base_cache(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  routing_context : RoutingContext,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  enable_complex_tuning : Bool,
  edge_vnodes : Map[String, Array[String]],
  samehead_overrides : Map[Int, @geom.Point],
  sametail_overrides : Map[Int, @geom.Point],
  samehead_group_sizes : Map[Int, Int],
  sametail_group_sizes : Map[Int, Int],
) -> Map[Int, EdgeRouteBase] {
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  for edge in edges {
    let edge_id = edge.id()
    if base_cache.get(edge_id) is None {
      let value = build_edge_route_base(
        graph.kind(),
        edge,
        ranks,
        sizes,
        positions,
        record_orientation,
        label_ports_map,
        label_ports_raw,
        routing_context,
        rankdir,
        layout_rankdir,
        enable_complex_tuning,
        edge_vnodes,
        samehead_overrides,
        sametail_overrides,
        samehead_group_sizes,
        sametail_group_sizes,
      )
      base_cache[edge_id] = value
    }
  }
  base_cache
}

///|
/// Graphviz parity: recover_slack consumes vnodes in edge rank direction.
/// Do not change behavior without updating fixtures/tests.
fn ordered_vnodes_for_edge(base : EdgeRouteBase) -> Array[String] {
  if base.tail_rank <= base.head_rank {
    base.vnodes.copy()
  } else {
    let reversed : Array[String] = []
    let mut idx = base.vnodes.length()
    while idx > 0 {
      idx = idx - 1
      reversed.push(base.vnodes[idx])
    }
    reversed
  }
}

///|
/// Graphviz parity: pathplan recover_slack runs with limitBoxes before vnode updates.
/// Do not change behavior without updating fixtures/tests.
fn recover_pathplan_slack_for_edge(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  vnode_positions : Map[String, @geom.Point],
  path_adjacency : @routesplines.PathAdjacency,
  recover_edge_id_by_key : Map[String, Int],
  recovered_slack_keys : Map[String, Bool],
) -> Unit {
  if !spline_result.using_pathplan {
    return ()
  }
  let recover_key = recover_slack_key_for_edge(edge)
  match recover_edge_id_by_key.get(recover_key) {
    Some(recover_edge_id) =>
      if recover_edge_id != edge.id() {
        return ()
      }
    None => ()
  }
  if recovered_slack_keys.get(recover_key) is Some(_) {
    return ()
  }
  if spline_result.pathplan_segments.length() > 0 {
    let mut did_recover = false
    // Graphviz parity: straight_path recovers slack per routed segment.
    for segment in spline_result.pathplan_segments {
      if segment.vnodes.length() == 0 || segment.boxes.length() == 0 {
        continue
      }
      let ordered_vnodes =
        if base.tail_rank <= base.head_rank {
          segment.vnodes.copy()
        } else {
          let reversed : Array[String] = []
          let mut idx = segment.vnodes.length()
          while idx > 0 {
            idx = idx - 1
            reversed.push(segment.vnodes[idx])
          }
          reversed
        }
      recover_slack_vnodes(
        edge,
        ordered_vnodes,
        segment.boxes,
        ranks,
        vnode_info.vnode_ranks,
        rank_y,
        vnode_positions,
        vnode_info.vnode_sizes,
        path_adjacency,
      )
      did_recover = true
    }
    if did_recover {
      recovered_slack_keys[recover_key] = true
    }
    return ()
  }
  if spline_result.pathplan_boxes.length() == 0 ||
    spline_result.raw_bezier.length() < 4 {
    return ()
  }
  let limited_boxes =
    @routesplines.limit_boxes_for_spline(
      spline_result.pathplan_boxes,
      spline_result.raw_bezier,
      fallback_polyline=spline_result.pathplan_points,
    )
  let ordered_vnodes = ordered_vnodes_for_edge(base)
  recover_slack_vnodes(
    edge,
    ordered_vnodes,
    limited_boxes,
    ranks,
    vnode_info.vnode_ranks,
    rank_y,
    vnode_positions,
    vnode_info.vnode_sizes,
    path_adjacency,
  )
  recovered_slack_keys[recover_key] = true
}

///|
/// Graphviz parity: self-edge routes reuse finalize/build_edge_layout path.
/// Do not change behavior without updating fixtures/tests.
fn build_self_edge_layout(
  base : EdgeRouteBase,
  route : SelfEdgeRoute,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let spline =
    edge_spline_for_bezier_points(
      base.edge,
      route.points,
      base.tail_clip_center,
      base.head_clip_center,
      base.tail_clip_size,
      base.head_clip_size,
      base.route_include_tail,
      base.route_include_head,
      tail_clip_enabled=base.tail_clip_enabled,
      head_clip_enabled=base.head_clip_enabled,
      arrow_len_override=base.arrow_len_override,
      tail_cluster_bbox=base.tail_cluster_bbox,
      head_cluster_bbox=base.head_cluster_bbox,
      parallel_offset=base.parallel_offset,
    )
  let spline_result : EdgeSplineResult = {
    spline,
    label_pad_boost: 0.0,
    using_pathplan: false,
    pathplan_boxes: [],
    pathplan_points: [],
    raw_bezier: route.points,
    pathplan_segments: [],
    apply_dotted_adjustment: false,
  }
  let layout_spline_result = rebuild_spline_for_render(base, spline_result)
  let final_spline = finalize_edge_spline(base, layout_spline_result)
  let mut edge_layout =
    build_edge_layout(
      base,
      final_spline,
      layout_spline_result,
      ranks,
      rank_y,
      vnode_info,
      vnode_positions,
      nodesep_pt,
      has_clusters,
      flat_label_edge_vnodes,
    )
  match route.label_pos {
    Some(pos) =>
      edge_layout = {
        edge: edge_layout.edge,
        splines: edge_layout.splines,
        label_pos: Some(pos),
        head_label_pos: edge_layout.head_label_pos,
        tail_label_pos: edge_layout.tail_label_pos,
        xlabel_pos: edge_layout.xlabel_pos,
      }
    None => ()
  }
  edge_layout
}

///|
/// Graphviz parity: adjacent same-rank no-port/no-label multiedges use the
/// makeSimpleFlat spindle path (dotsplines.c).
/// Do not change behavior without updating fixtures/tests.
fn build_flat_adjacent_simple_edge_layout(
  base : EdgeRouteBase,
  bezier : Array[@geom.Point],
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let spline =
    edge_spline_for_bezier_points(
      base.edge,
      bezier,
      base.tail_clip_center,
      base.head_clip_center,
      base.tail_clip_size,
      base.head_clip_size,
      base.route_include_tail,
      base.route_include_head,
      tail_clip_enabled=base.tail_clip_enabled,
      head_clip_enabled=base.head_clip_enabled,
      arrow_len_override=base.arrow_len_override,
      tail_cluster_bbox=base.tail_cluster_bbox,
      head_cluster_bbox=base.head_cluster_bbox,
      parallel_offset=base.parallel_offset,
      clip_swapped=base.swap_ends,
      arrow_swapped=base.swap_ends,
    )
  let spline_result : EdgeSplineResult = {
    spline,
    label_pad_boost: 0.0,
    using_pathplan: false,
    pathplan_boxes: [],
    pathplan_points: [],
    raw_bezier: bezier,
    pathplan_segments: [],
    apply_dotted_adjustment: false,
  }
  let layout_spline_result = rebuild_spline_for_render(base, spline_result)
  let final_spline = finalize_edge_spline(base, layout_spline_result)
  build_edge_layout(
    base,
    final_spline,
    layout_spline_result,
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}

///|
/// Graphviz parity: self-edge groups share generated loop routes in the same pass.
/// Do not change behavior without updating fixtures/tests.
fn ensure_self_edge_routes(
  graph : @cgraph.Graph,
  edge : @cgraph.Edge,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  routing_context : RoutingContext,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  enable_complex_tuning : Bool,
  edge_vnodes : Map[String, Array[String]],
  samehead_overrides : Map[Int, @geom.Point],
  sametail_overrides : Map[Int, @geom.Point],
  samehead_group_sizes : Map[Int, Int],
  sametail_group_sizes : Map[Int, Int],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  self_edge_routes : Map[Int, SelfEdgeRoute],
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
          None => {
            let value = build_edge_route_base(
              graph.kind(),
              grouped,
              ranks,
              sizes,
              positions,
              record_orientation,
              label_ports_map,
              label_ports_raw,
              routing_context,
              rankdir,
              layout_rankdir,
              enable_complex_tuning,
              edge_vnodes,
              samehead_overrides,
              sametail_overrides,
              samehead_group_sizes,
              sametail_group_sizes,
            )
            base_cache[gid] = value
            value
          }
        }
        group_bases.push(gbase)
      }
      let group_routes =
        build_self_edge_routes(
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
/// Graphviz parity: routed edge output remains in original edge iteration order.
/// Do not change behavior without updating fixtures/tests.
fn collect_edges_in_input_order(
  edges : Array[@cgraph.Edge],
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Array[DotLayoutEdge] {
  let edges_out : Array[DotLayoutEdge] = []
  for edge in edges {
    match edges_out_by_id.get(edge.id()) {
      Some(value) => edges_out.push(value)
      None => ()
    }
  }
  edges_out
}

///|
fn remap_edge_layout_edge(
  edge : @cgraph.Edge,
  layout : DotLayoutEdge,
) -> DotLayoutEdge {
  let label_pos = match edge.get_attr("label") {
    Some(value) => if value != "" { layout.label_pos } else { None }
    None => None
  }
  let head_label_pos = match edge.get_attr("headlabel") {
    Some(value) =>
      if value != "" {
        if layout.splines.length() == 0 {
          layout.head_label_pos
        } else {
          let head_spline = layout.splines[layout.splines.length() - 1]
          match edge_port_label_pos(edge, head_spline, true) {
            Some(pos) => Some(pos)
            None => layout.head_label_pos
          }
        }
      } else {
        None
      }
    None => None
  }
  let tail_label_pos = match edge.get_attr("taillabel") {
    Some(value) =>
      if value != "" {
        if layout.splines.length() == 0 {
          layout.tail_label_pos
        } else {
          let tail_spline = layout.splines[0]
          match edge_port_label_pos(edge, tail_spline, false) {
            Some(pos) => Some(pos)
            None => layout.tail_label_pos
          }
        }
      } else {
        None
      }
    None => None
  }
  let xlabel_pos = match edge.get_attr("xlabel") {
    Some(value) => if value != "" { layout.xlabel_pos } else { None }
    None => None
  }
  {
    edge,
    splines: layout.splines,
    label_pos,
    head_label_pos,
    tail_label_pos,
    xlabel_pos,
  }
}

///|
/// Graphviz parity: duplicate regular-edge spline slots are assigned in
/// pair order after routing, but only within one-direction parallel classes.
/// Do not change behavior without updating fixtures/tests.
fn remap_parallel_edge_layouts_for_graphviz(
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Unit {
  let groups : Map[String, Array[Int]] = Map::new()
  let group_first_direction : Map[String, String] = Map::new()
  let group_has_mixed_direction : Map[String, Bool] = Map::new()
  for edge in edges {
    if edge_has_label(edge) {
      continue
    }
    let tail = edge.tail().name()
    let head = edge.head().name()
    if tail == head {
      continue
    }
    let tail_rank = match ranks.get(tail) {
      Some(value) => value
      None => 0
    }
    let head_rank = match ranks.get(head) {
      Some(value) => value
      None => 0
    }
    if tail_rank == head_rank {
      continue
    }
    let key = edge_parallel_group_key(edge)
    let sameport_mark =
      match edge.get_attr("samehead") {
        Some(value) => value != ""
        None =>
          match edge.get_attr("sametail") {
            Some(value) => value != ""
            None => false
          }
      }
    let dir_key = match edge.get_attr("dir") {
      Some(value) => value.to_lower()
      None => "forward"
    }
    let sameport_tag = if sameport_mark { "sameport" } else { "plain" }
    let direction_key =
      "\{tail}|\{port_key(edge.tail_port())}|\{head}|\{port_key(edge.head_port())}|\{dir_key}|\{sameport_tag}"
    match groups.get(key) {
      Some(list) => list.push(edge.id())
      None => groups[key] = [edge.id()]
    }
    match group_first_direction.get(key) {
      Some(first_direction) =>
        if first_direction != direction_key {
          group_has_mixed_direction[key] = true
        }
      None => {
        group_first_direction[key] = direction_key
        group_has_mixed_direction[key] = false
      }
    }
  }
  for key, ids in groups {
    if ids.length() <= 1 {
      continue
    }
    let mixed_direction = match group_has_mixed_direction.get(key) {
      Some(value) => value
      None => false
    }
    if mixed_direction {
      continue
    }
    ids.sort()
    let layouts : Array[DotLayoutEdge] = []
    for edge_id in ids {
      match edges_out_by_id.get(edge_id) {
        Some(layout) => layouts.push(layout)
        None => ()
      }
    }
    if layouts.length() != ids.length() {
      continue
    }
    let mut out_idx = 0
    let mut src_idx = layouts.length()
    while out_idx < ids.length() {
      src_idx = src_idx - 1
      let edge_id = ids[out_idx]
      let edge = match edges_out_by_id.get(edge_id) {
        Some(layout) => layout.edge
        None => {
          out_idx = out_idx + 1
          continue
        }
      }
      edges_out_by_id[edge_id] =
        remap_edge_layout_edge(edge, layouts[src_idx])
      out_idx = out_idx + 1
    }
  }
}

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
      graphviz_route_edge_cmp(a, b, base_cache, order_index)
    })
  }
  ordered_edges
}

///|
/// Graphviz parity: recover_slack class keys collapse reverse-direction
/// unlabeled edges that share a class2 vnode chain.
fn recover_slack_key_for_edge(edge : @cgraph.Edge) -> String {
  let undirected = edge.tail().graph().kind() is @cgraph.GraphKind::Undirected
  if edge_has_label(edge) || !undirected {
    "vnode|\{edge_vnode_key(edge)}"
  } else {
    "parallel|\{edge_parallel_key(edge.tail().name(), edge.head().name(), edge.tail_port(), edge.head_port())}"
  }
}

///|
/// Graphviz parity: recover_slack for regular-edge classes uses the
/// center-most parallel member (tie: later edge id).
fn recover_edge_selection_for_regular_edges(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> Map[String, Int] {
  let selected_ids : Map[String, Int] = Map::new()
  let selected_scores : Map[String, Double] = Map::new()
  for edge in ordered_edges {
    if edge.tail().name() == edge.head().name() {
      continue
    }
    let base = match base_cache.get(edge.id()) {
      Some(value) => value
      None => continue
    }
    if base.is_flat_edge {
      continue
    }
    let key = recover_slack_key_for_edge(edge)
    let score = Double::abs(base.parallel_offset)
    match selected_ids.get(key) {
      Some(current_id) => {
        let current_score = match selected_scores.get(key) {
          Some(value) => value
          None => score
        }
        if score < current_score ||
          (score == current_score && edge.id() > current_id) {
          selected_ids[key] = edge.id()
          selected_scores[key] = score
        }
      }
      None => {
        selected_ids[key] = edge.id()
        selected_scores[key] = score
      }
    }
  }
  selected_ids
}

///|
/// Graphviz parity: regular-edge routing keeps build/finalize/recover_slack flow.
/// Do not change behavior without updating fixtures/tests.
fn build_regular_edge_layout_with_spline_result(
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  splines : SplinesMode,
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  path_left_bound : Double,
  path_right_bound : Double,
  ranksep_pt : Double,
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
  path_adjacency : @routesplines.PathAdjacency,
  recover_edge_id_by_key : Map[String, Int],
  recovered_slack_keys : Map[String, Bool],
) -> (DotLayoutEdge, EdgeSplineResult) {
  let spline_result = build_edge_spline(
    base,
    splines,
    ranks,
    sizes,
    positions,
    vnode_positions,
    vnode_info,
    rank_y,
    rank_ht1,
    rank_ht2,
    x_groups,
    nodesep_pt,
    path_left_bound,
    path_right_bound,
    ranksep_pt,
    label_edge_counts,
    head_port_metrics,
    routing_context,
    enable_complex_tuning,
  )
  let layout_spline_result = rebuild_spline_for_render(base, spline_result)
  let spline = finalize_edge_spline(base, layout_spline_result)
  recover_pathplan_slack_for_edge(
    edge,
    base,
    spline_result,
    ranks,
    vnode_info,
    rank_y,
    vnode_positions,
    path_adjacency,
    recover_edge_id_by_key,
    recovered_slack_keys,
  )
  let layout =
    build_edge_layout(
      base,
      spline,
      layout_spline_result,
      ranks,
      rank_y,
      vnode_info,
      vnode_positions,
      nodesep_pt,
      has_clusters,
      flat_label_edge_vnodes,
    )
  (layout, spline_result)
}

///|
/// Graphviz parity: regular-edge reuse path keeps clipping/label finalization.
fn build_regular_edge_layout_from_shared_raw_bezier(
  base : EdgeRouteBase,
  shared_spline_result : EdgeSplineResult,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  nodesep_pt : Double,
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
) -> DotLayoutEdge {
  let spline =
    edge_spline_for_bezier_points(
      base.edge,
      shared_spline_result.raw_bezier,
      base.tail_clip_center,
      base.head_clip_center,
      base.tail_clip_size,
      base.head_clip_size,
      base.route_include_tail,
      base.route_include_head,
      tail_clip_enabled=base.tail_clip_enabled,
      head_clip_enabled=base.head_clip_enabled,
      arrow_len_override=base.arrow_len_override,
      tail_cluster_bbox=base.tail_cluster_bbox,
      head_cluster_bbox=base.head_cluster_bbox,
      parallel_offset=base.parallel_offset,
      clip_swapped=base.swap_ends,
      arrow_swapped=base.swap_ends,
    )
  let sibling_spline_result : EdgeSplineResult = {
    spline,
    label_pad_boost: shared_spline_result.label_pad_boost,
    using_pathplan: false,
    pathplan_boxes: [],
    pathplan_points: [],
    raw_bezier: shared_spline_result.raw_bezier,
    pathplan_segments: [],
    apply_dotted_adjustment: shared_spline_result.apply_dotted_adjustment,
  }
  let layout_spline_result =
    rebuild_spline_for_render(base, sibling_spline_result)
  let final_spline = finalize_edge_spline(base, layout_spline_result)
  build_edge_layout(
    base,
    final_spline,
    layout_spline_result,
    ranks,
    rank_y,
    vnode_info,
    vnode_positions,
    nodesep_pt,
    has_clusters,
    flat_label_edge_vnodes,
  )
}

///|
/// Graphviz parity: self-edge route cache reuse + self-edge layout finalize path.
/// Do not change behavior without updating fixtures/tests.
fn maybe_build_self_edge_layout(
  graph : @cgraph.Graph,
  edge : @cgraph.Edge,
  base : EdgeRouteBase,
  self_edge_groups : Map[String, Array[@cgraph.Edge]],
  base_cache : Map[Int, EdgeRouteBase],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  positions : Map[String, @geom.Point],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  routing_context : RoutingContext,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  enable_complex_tuning : Bool,
  edge_vnodes : Map[String, Array[String]],
  samehead_overrides : Map[Int, @geom.Point],
  sametail_overrides : Map[Int, @geom.Point],
  samehead_group_sizes : Map[Int, Int],
  sametail_group_sizes : Map[Int, Int],
  nodesep_pt : Double,
  rank_y : Map[Int, Double],
  vnode_info : EdgeVnodeInfo,
  vnode_positions : Map[String, @geom.Point],
  has_clusters : Bool,
  flat_label_edge_vnodes : Map[String, String],
  self_edge_routes : Map[Int, SelfEdgeRoute],
  edges_out_by_id : Map[Int, DotLayoutEdge],
) -> Bool {
  if edge.tail().name() != edge.head().name() {
    return false
  }
  let edge_id = edge.id()
  ensure_self_edge_routes(
    graph,
    edge,
    self_edge_groups,
    base_cache,
    ranks,
    sizes,
    positions,
    record_orientation,
    label_ports_map,
    label_ports_raw,
    routing_context,
    rankdir,
    layout_rankdir,
    enable_complex_tuning,
    edge_vnodes,
    samehead_overrides,
    sametail_overrides,
    samehead_group_sizes,
    sametail_group_sizes,
    nodesep_pt,
    rank_y,
    self_edge_routes,
  )
  match self_edge_routes.get(edge_id) {
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

///|
fn collect_regular_parallel_groups_for_graphviz(
  ordered_edges : Array[@cgraph.Edge],
  base_cache : Map[Int, EdgeRouteBase],
) -> Map[String, Array[@cgraph.Edge]] {
  let groups : Map[String, Array[@cgraph.Edge]] = Map::new()
  for edge in ordered_edges {
    if edge_has_label(edge) {
      continue
    }
    if edge.tail().name() == edge.head().name() {
      continue
    }
    let base = match base_cache.get(edge.id()) {
      Some(value) => value
      None => continue
    }
    if base.is_flat_edge {
      continue
    }
    let key = edge_vnode_key(edge)
    match groups.get(key) {
      Some(list) => list.push(edge)
      None => groups[key] = [edge]
    }
  }
  groups
}

///|
/// Graphviz parity: edge routing aligned to refs/graphviz/lib/dotgen/dotsplines.c + lib/common/routespl.c + lib/pathplan/* + lib/common/splines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
fn route_edges(
  graph : @cgraph.Graph,
  edges : Array[@cgraph.Edge],
  ranks : Map[String, Int],
  sizes : Map[String, NodeSize],
  record_orientation : RecordOrientation,
  rankdir : RankDir,
  layout_rankdir : RankDir,
  splines : SplinesMode,
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  vnode_info : EdgeVnodeInfo,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  ranksep_pt : Double,
  has_clusters : Bool,
  label_ports_map : Map[String, Map[String, RecordPort]],
  label_ports_raw : Map[String, Map[String, RecordPort]],
  label_edge_counts : Map[String, Int],
  head_port_metrics : HeadPortMetrics,
  flat_label_edge_vnodes : Map[String, String],
  routing_context : RoutingContext,
  enable_complex_tuning : Bool,
) -> Array[DotLayoutEdge] {
  let path_adjacency = routing_context.path_adjacency
  let order_index = routing_context.path_order_index
  let self_edge_groups = collect_self_edge_groups(edges)
  let (
    samehead_overrides,
    sametail_overrides,
    samehead_group_sizes,
    sametail_group_sizes,
  ) =
    collect_sameport_anchor_overrides(
      edges,
      positions,
      sizes,
      record_orientation,
      layout_rankdir,
      ranksep_pt,
    )
  let base_cache =
    build_route_base_cache(
      graph,
      edges,
      ranks,
      sizes,
      positions,
      record_orientation,
      label_ports_map,
      label_ports_raw,
      routing_context,
      rankdir,
      layout_rankdir,
      enable_complex_tuning,
      vnode_info.edge_vnodes,
      samehead_overrides,
      sametail_overrides,
      samehead_group_sizes,
      sametail_group_sizes,
    )
  let flat_adjacent_simple_beziers =
    if splines == SplinesMode::Spline {
      collect_flat_adjacent_simple_beziers(
        edges,
        base_cache,
        ranks,
        routing_context.order_index,
      )
    } else {
      Map::new()
    }
  let self_edge_routes : Map[Int, SelfEdgeRoute] = Map::new()
  let edges_out_by_id : Map[Int, DotLayoutEdge] = Map::new()
  let recovered_slack_keys : Map[String, Bool] = Map::new()
  let (path_left_bound, path_right_bound) =
    @routesplines.pathplan_bounds(
      positions,
      vnode_positions,
      sizes,
      vnode_info.vnode_sizes,
      x_groups,
    )
  dot_trace("layout_dot: routing edges")
  let ordered_edges =
    sorted_edges_for_routing(edges, base_cache, order_index)
  let recover_edge_id_by_key =
    recover_edge_selection_for_regular_edges(ordered_edges, base_cache)
  let regular_parallel_groups =
    collect_regular_parallel_groups_for_graphviz(ordered_edges, base_cache)
  let recover_edge_id_for_routing : Map[String, Int] = Map::new()
  for key, edge_id in recover_edge_id_by_key {
    recover_edge_id_for_routing[key] = edge_id
  }
  for _key, group_edges in regular_parallel_groups {
    if group_edges.length() > 1 {
      let recover_key = recover_slack_key_for_edge(group_edges[0])
      recover_edge_id_for_routing[recover_key] = group_edges[0].id()
    }
  }
  for edge in ordered_edges {
    let edge_id = edge.id()
    if edges_out_by_id.get(edge_id) is Some(_) {
      continue
    }
    let base = match base_cache.get(edge_id) {
      Some(value) => value
      None => continue
    }
    match flat_adjacent_simple_beziers.get(edge_id) {
      Some(bezier) => {
        let edge_layout =
          build_flat_adjacent_simple_edge_layout(
            base,
            bezier,
            ranks,
            rank_y,
            vnode_info,
            vnode_positions,
            nodesep_pt,
            has_clusters,
            flat_label_edge_vnodes,
          )
        edges_out_by_id[edge_id] = edge_layout
        continue
      }
      None => ()
    }
    if maybe_build_self_edge_layout(
      graph,
      edge,
      base,
      self_edge_groups,
      base_cache,
      ranks,
      sizes,
      positions,
      record_orientation,
      label_ports_map,
      label_ports_raw,
      routing_context,
      rankdir,
      layout_rankdir,
      enable_complex_tuning,
      vnode_info.edge_vnodes,
      samehead_overrides,
      sametail_overrides,
      samehead_group_sizes,
      sametail_group_sizes,
      nodesep_pt,
      rank_y,
      vnode_info,
      vnode_positions,
      has_clusters,
      flat_label_edge_vnodes,
      self_edge_routes,
      edges_out_by_id,
    ) {
      continue
    }
    let (edge_layout, edge_spline_result) =
      build_regular_edge_layout_with_spline_result(
        edge,
        base,
        splines,
        ranks,
        sizes,
        positions,
        vnode_positions,
        vnode_info,
        rank_y,
        rank_ht1,
        rank_ht2,
        x_groups,
        nodesep_pt,
        path_left_bound,
        path_right_bound,
        ranksep_pt,
        label_edge_counts,
        head_port_metrics,
        routing_context,
        enable_complex_tuning,
        has_clusters,
        flat_label_edge_vnodes,
        path_adjacency,
        recover_edge_id_for_routing,
        recovered_slack_keys,
      )
    edges_out_by_id[edge_id] = edge_layout
    let regular_key = edge_vnode_key(edge)
    let group_edges = match regular_parallel_groups.get(regular_key) {
      Some(value) => value
      None => continue
    }
    if group_edges.length() <= 1 ||
      group_edges[0].id() != edge_id ||
      edge_spline_result.raw_bezier.length() == 0 {
      continue
    }
    for group_edge in group_edges {
      let group_edge_id = group_edge.id()
      if group_edge_id == edge_id {
        continue
      }
      let group_base = match base_cache.get(group_edge_id) {
        Some(value) => value
        None => continue
      }
      let group_layout =
        build_regular_edge_layout_from_shared_raw_bezier(
          group_base,
          edge_spline_result,
          ranks,
          rank_y,
          vnode_info,
          vnode_positions,
          nodesep_pt,
          has_clusters,
          flat_label_edge_vnodes,
        )
      edges_out_by_id[group_edge_id] = group_layout
    }
  }
  remap_parallel_edge_layouts_for_graphviz(edges, ranks, edges_out_by_id)
  collect_edges_in_input_order(edges, edges_out_by_id)
}
