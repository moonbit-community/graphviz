///|
type NodeSize = @dot_shared.NodeSize

///|
type RankDir = @dot_shared.RankDir

///|
fn default_node_width_in() -> Double {
  @dot_shared.default_node_width_in()
}

///|
fn default_node_height_in() -> Double {
  @dot_shared.default_node_height_in()
}

///|
fn node_size_from_points(width_pt : Double, height_pt : Double) -> NodeSize {
  @dot_shared.node_size_from_points(width_pt, height_pt)
}

///|
fn port_is_explicit(port : @cgraph.Port?) -> Bool {
  @dot_shared.port_is_explicit(port)
}

///|
fn edge_vnode_key(edge : @cgraph.Edge) -> String {
  @dot_shared.edge_vnode_key(edge)
}

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b { a } else { b }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b { a } else { b }
}

///|
const ROUTE_FUDGE : Double = 4.0

///|
const ROUTE_MIN_WIDTH : Double = 16.0

///|
///|
///|
fn merge_positions(
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
) -> Map[String, @geom.Point] {
  let merged : Map[String, @geom.Point] = Map::new()
  for name, pos in positions {
    merged[name] = pos
  }
  for name, pos in vnode_positions {
    merged[name] = pos
  }
  merged
}

///|
fn merge_sizes(
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
) -> Map[String, NodeSize] {
  let merged : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    merged[name] = size
  }
  for name, size in vnode_sizes {
    merged[name] = size
  }
  merged
}

///|
fn pathplan_sizes(
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  _nodesep_pt : Double,
) -> Map[String, NodeSize] {
  let adjusted : Map[String, NodeSize] = Map::new()
  for name, size in sizes {
    adjusted[name] = size
  }
  for name, size in vnode_sizes {
    adjusted[name] = size
  }
  adjusted
}

///|
fn compute_horizontal_bounds(
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  _nodesep_pt : Double,
) -> (Double, Double) {
  let mut min_x = 0.0
  let mut max_x = 0.0
  let mut seen = false
  for name, pos in positions {
    let size = match sizes.get(name) {
      Some(value) => value
      None => continue
    }
    let left = pos.x - size.left_pt
    let right = pos.x + size.right_pt
    if !seen {
      min_x = left
      max_x = right
      seen = true
    } else {
      if left < min_x {
        min_x = left
      }
      if right > max_x {
        max_x = right
      }
    }
  }
  if !seen {
    (0.0, 0.0)
  } else {
    (min_x - ROUTE_MIN_WIDTH, max_x + ROUTE_MIN_WIDTH)
  }
}

///|
fn neighbor_names_for_rank(
  name : String,
  rank : Int,
  x_groups : Map[Int, Array[String]],
  vnode_sizes : Map[String, NodeSize],
  skip_virtual_neighbors : Bool,
) -> (String?, String?) {
  match x_groups.get(rank) {
    Some(list) => {
      let mut idx = 0
      while idx < list.length() {
        if list[idx] == name {
          let mut left : String? = None
          let mut left_idx = idx - 1
          while left_idx >= 0 {
            let candidate = list[left_idx]
            if !(skip_virtual_neighbors && vnode_sizes.get(candidate) is Some(_)) {
              left = Some(candidate)
              break
            }
            left_idx = left_idx - 1
          }
          let mut right : String? = None
          let mut right_idx = idx + 1
          while right_idx < list.length() {
            let candidate = list[right_idx]
            if !(skip_virtual_neighbors && vnode_sizes.get(candidate) is Some(_)) {
              right = Some(candidate)
              break
            }
            right_idx = right_idx + 1
          }
          return (left, right)
        }
        idx = idx + 1
      }
    }
    None => ()
  }
  (None, None)
}

///|
fn size_for_name(name : String, sizes : Map[String, NodeSize]) -> NodeSize {
  match sizes.get(name) {
    Some(value) => value
    None =>
      node_size_from_points(
        default_node_width_in() * 72.0,
        default_node_height_in() * 72.0,
      )
  }
}

///|
fn cluster_key_for_name(
  name : String,
  cluster_keys : Map[String, String],
  vnode_clusters : Map[String, String],
) -> String {
  match vnode_clusters.get(name) {
    Some(value) => value
    None =>
      match cluster_keys.get(name) {
        Some(value) => value
        None => ""
      }
  }
}

///|
///|
fn maximal_bbox_for_name(
  name : String,
  rank : Int,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  vnode_clusters : Map[String, String],
  cluster_bboxes : Map[String, @geom.Rect],
  x_groups : Map[Int, Array[String]],
  nodesep_pt : Double,
  splinesep_pt : Double,
  left_bound : Double,
  right_bound : Double,
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  tail_cluster : String,
  head_cluster : String,
) -> @geom.Rect? {
  let pos = match positions.get(name) {
    Some(value) => value
    None => return None
  }
  let size = size_for_name(name, sizes)
  let is_virtual = vnode_sizes.get(name) is Some(_)
  let (left_neighbor, right_neighbor) =
    neighbor_names_for_rank(name, rank, x_groups, vnode_sizes, is_virtual)
  let neighbor_sep = (neighbor : String) => {
    let neighbor_size = size_for_name(neighbor, sizes)
    let is_virtual = vnode_sizes.get(neighbor) is Some(_) || neighbor_size.height_pt <= 0.0
    if is_virtual { splinesep_pt } else { nodesep_pt / 2.0 }
  }
  let mut b = pos.x - size.left_pt - ROUTE_FUDGE
  match left_neighbor {
    Some(neighbor) => {
      let neighbor_cluster =
        cluster_key_for_name(neighbor, cluster_keys, vnode_clusters)
      if neighbor_cluster != "" &&
        neighbor_cluster != tail_cluster &&
        neighbor_cluster != head_cluster {
        match cluster_bboxes.get(neighbor_cluster) {
          Some(rect) => {
            let nb = rect.urx + splinesep_pt
            if nb < b {
              b = nb
            }
          }
          None => ()
        }
      } else {
        match positions.get(neighbor) {
          Some(neighbor_pos) => {
            let neighbor_size = size_for_name(neighbor, sizes)
            let nb = neighbor_pos.x + neighbor_size.right_pt + neighbor_sep(neighbor)
            if nb < b {
              b = nb
            }
          }
          None => ()
        }
      }
    }
    None =>
      if left_bound < b {
      b = left_bound
    }
  }
  let mut llx = b.round()
  let mut br = pos.x + size.right_pt + ROUTE_FUDGE
  match right_neighbor {
    Some(neighbor) => {
      let neighbor_cluster =
        cluster_key_for_name(neighbor, cluster_keys, vnode_clusters)
      if neighbor_cluster != "" &&
        neighbor_cluster != tail_cluster &&
        neighbor_cluster != head_cluster {
        match cluster_bboxes.get(neighbor_cluster) {
          Some(rect) => {
            let nb = rect.llx - splinesep_pt
            if nb > br {
              br = nb
            }
          }
          None => ()
        }
      } else {
        match positions.get(neighbor) {
          Some(neighbor_pos) => {
            let neighbor_size = size_for_name(neighbor, sizes)
            let nb = neighbor_pos.x - neighbor_size.left_pt - neighbor_sep(neighbor)
            if nb > br {
              br = nb
            }
          }
          None => ()
        }
      }
    }
    None =>
      if right_bound > br {
      br = right_bound
    }
  }
  let mut urx = br.round()
  if llx >= urx {
    let mid = (llx + urx) / 2.0
    llx = mid - ROUTE_MIN_WIDTH / 2.0
    urx = mid + ROUTE_MIN_WIDTH / 2.0
  }
  let ht1 = match rank_ht1.get(rank) {
    Some(value) => value
    None => 0.0
  }
  let ht2 = match rank_ht2.get(rank) {
    Some(value) => value
    None => 0.0
  }
  let mut lly = pos.y - ht1
  let mut ury = pos.y + ht2
  if lly > ury {
    let tmp = lly
    lly = ury
    ury = tmp
  }
  Some({ llx, lly, urx, ury })
}

///|
///|
fn rank_gap_box(
  rank_a : Int,
  rank_b : Int,
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  left_bound : Double,
  right_bound : Double,
) -> @geom.Rect? {
  if rank_a == rank_b {
    return None
  }
  let upper = if rank_a < rank_b { rank_a } else { rank_b }
  let lower = if rank_a < rank_b { rank_b } else { rank_a }
  let upper_y = match rank_y.get(upper) {
    Some(value) => value
    None => return None
  }
  let lower_y = match rank_y.get(lower) {
    Some(value) => value
    None => return None
  }
  let upper_ht1 = match rank_ht1.get(upper) {
    Some(value) => value
    None => 0.0
  }
  let lower_ht2 = match rank_ht2.get(lower) {
    Some(value) => value
    None => 0.0
  }
  // rank_y increases upward; gap spans from upper bottom to lower top.
  let upper_bottom = upper_y - upper_ht1
  let lower_top = lower_y + lower_ht2
  let lly = min_double(upper_bottom, lower_top)
  let ury = max_double(upper_bottom, lower_top)
  if lly == ury {
    return None
  }
  let mut llx = left_bound
  let mut urx = right_bound
  if llx > urx {
    let tmp = llx
    llx = urx
    urx = tmp
  }
  if urx - llx < ROUTE_MIN_WIDTH {
    let mid = (llx + urx) / 2.0
    llx = mid - ROUTE_MIN_WIDTH / 2.0
    urx = mid + ROUTE_MIN_WIDTH / 2.0
  }
  Some({ llx, lly, urx, ury })
}

///|
///|
fn boxes_to_polygon_points(boxes : Array[@geom.Rect]) -> Array[@geom.Point] {
  if boxes.length() == 0 {
    return []
  }
  let mut flip = false
  let mut boxes_copy = boxes
  if boxes.length() > 1 && boxes[0].lly > boxes[1].lly {
    flip = true
    let flipped : Array[@geom.Rect] = []
    for box in boxes {
      flipped.push({ llx: box.llx, lly: -box.ury, urx: box.urx, ury: -box.lly })
    }
    boxes_copy = flipped
  }
  let polypoints : Array[@geom.Point] = []
  let boxn = boxes_copy.length()
  for bi in 0..<boxn {
    let box = boxes_copy[bi]
    let mut prev = 0
    let mut next = 0
    if bi > 0 {
      prev = if boxes_copy[bi].lly > boxes_copy[bi - 1].lly { -1 } else { 1 }
    }
    if bi + 1 < boxn {
      next = if boxes_copy[bi + 1].lly > boxes_copy[bi].lly { 1 } else { -1 }
    }
    if prev != next {
      if next == -1 || prev == 1 {
        polypoints.push({ x: box.llx, y: box.ury })
        polypoints.push({ x: box.llx, y: box.lly })
      } else {
        polypoints.push({ x: box.urx, y: box.lly })
        polypoints.push({ x: box.urx, y: box.ury })
      }
    } else if prev == 0 {
      polypoints.push({ x: box.llx, y: box.ury })
      polypoints.push({ x: box.llx, y: box.lly })
    } else if !(prev == -1 && next == -1) {
      return []
    }
  }
  let mut bi = boxn
  while bi > 0 {
    bi = bi - 1
    let box = boxes_copy[bi]
    let mut prev = 0
    let mut next = 0
    if bi + 1 < boxn {
      prev = if boxes_copy[bi].lly > boxes_copy[bi + 1].lly { -1 } else { 1 }
    }
    if bi > 0 {
      next = if boxes_copy[bi - 1].lly > boxes_copy[bi].lly { 1 } else { -1 }
    }
    if prev != next {
      if next == -1 || prev == 1 {
        polypoints.push({ x: box.llx, y: box.ury })
        polypoints.push({ x: box.llx, y: box.lly })
      } else {
        polypoints.push({ x: box.urx, y: box.lly })
        polypoints.push({ x: box.urx, y: box.ury })
      }
    } else if prev == 0 {
      polypoints.push({ x: box.urx, y: box.lly })
      polypoints.push({ x: box.urx, y: box.ury })
    } else {
      if !(prev == -1 && next == -1) {
        return []
      }
      polypoints.push({ x: box.urx, y: box.lly })
      polypoints.push({ x: box.urx, y: box.ury })
      polypoints.push({ x: box.llx, y: box.ury })
      polypoints.push({ x: box.llx, y: box.lly })
    }
  }
  if !flip {
    return polypoints
  }
  let restored : Array[@geom.Point] = []
  for point in polypoints {
    restored.push({ x: point.x, y: -point.y })
  }
  restored
}

///|
fn dedupe_polyline_points(points : Array[@geom.Point]) -> Array[@geom.Point] {
  if points.length() <= 1 {
    return points
  }
  let out : Array[@geom.Point] = []
  out.push(points[0])
  let mut idx = 1
  while idx < points.length() {
    let p = points[idx]
    let last = out[out.length() - 1]
    if p.x != last.x || p.y != last.y {
      out.push(p)
    }
    idx = idx + 1
  }
  out
}

///|
fn nudge_route_endpoints(
  start : @geom.Point,
  end : @geom.Point,
  rankdir : RankDir,
  tail_explicit : Bool,
  head_explicit : Bool,
) -> (@geom.Point, @geom.Point) {
  let mut nudged_start = start
  let mut nudged_end = end
  let step = 1.0
  match rankdir {
    RankDir::TB | RankDir::BT => {
      if !tail_explicit {
        let dir = if end.y >= start.y { 1.0 } else { -1.0 }
        nudged_start = { x: start.x, y: start.y + dir * step }
      }
      if !head_explicit {
        let dir = if start.y >= end.y { 1.0 } else { -1.0 }
        nudged_end = { x: end.x, y: end.y + dir * step }
      }
    }
    RankDir::LR | RankDir::RL => {
      if !tail_explicit {
        let dir = if end.x >= start.x { 1.0 } else { -1.0 }
        nudged_start = { x: start.x + dir * step, y: start.y }
      }
      if !head_explicit {
        let dir = if start.x >= end.x { 1.0 } else { -1.0 }
        nudged_end = { x: end.x + dir * step, y: end.y }
      }
    }
  }
  (nudged_start, nudged_end)
}

///|
fn route_pathplan_from_boxes(
  boxes : Array[@geom.Rect],
  start : @geom.Point,
  end : @geom.Point,
  rankdir : RankDir,
  tail_explicit : Bool,
  head_explicit : Bool,
) -> (Array[@geom.Point], Array[@geom.Point])? {
  if boxes.length() < 2 {
    return None
  }
  let polygon = boxes_to_polygon_points(boxes)
  if polygon.length() < 3 {
    return None
  }
  if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
    let poly_parts : Array[String] = []
    for point in polygon {
      poly_parts.push("\{point.x},\{point.y}")
    }
    let joined = poly_parts.join(" ")
    println("  pathplan polygon: \{joined}")
  }
  let (start_in, end_in) =
    nudge_route_endpoints(start, end, rankdir, tail_explicit, head_explicit)
  let path = @pathplan.shortest_path_in_poly(polygon, start_in, end_in)
  if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
    let parts : Array[String] = []
    for point in path {
      parts.push("\{point.x},\{point.y}")
    }
    let joined = parts.join(" ")
    println("  pathplan polyline: \{joined}")
  }
  if path.length() < 2 {
    return None
  }
  Some((dedupe_polyline_points(path), polygon))
}

///|
fn polygon_edges(
  polygon : Array[@geom.Point],
) -> Array[(@geom.Point, @geom.Point)] {
  let edges : Array[(@geom.Point, @geom.Point)] = []
  if polygon.length() < 2 {
    return edges
  }
  for i in 0..<polygon.length() {
    let next = if i + 1 < polygon.length() { i + 1 } else { 0 }
    edges.push((polygon[i], polygon[next]))
  }
  edges
}

///|
fn regular_end_box_bottom(box : @geom.Rect, y : Double) -> @geom.Rect {
  { llx: box.llx, lly: y, urx: box.urx, ury: box.lly }
}

///|
fn regular_end_box_top(box : @geom.Rect, y : Double) -> @geom.Rect {
  { llx: box.llx, lly: box.ury, urx: box.urx, ury: y }
}

///|
fn adjust_regular_path(
  boxes : Array[@geom.Rect],
  fb : Int,
  lb : Int,
) -> Array[@geom.Rect] {
  if boxes.length() == 0 {
    return boxes
  }
  let adjusted = boxes.copy()
  let max_idx = adjusted.length() - 1
  let mut start = fb - 1
  if start < 0 {
    start = 0
  }
  let mut end = lb
  if end > max_idx {
    end = max_idx
  }
  if start <= end {
    let mut i = start
    while i <= end {
      let mut box = adjusted[i]
      if (i - fb) % 2 == 0 {
        if box.llx >= box.urx {
          let mid = (box.llx + box.urx) / 2.0
          box = { llx: mid - ROUTE_MIN_WIDTH / 2.0, lly: box.lly, urx: mid + ROUTE_MIN_WIDTH / 2.0, ury: box.ury }
        }
      } else {
        if box.llx + ROUTE_MIN_WIDTH > box.urx {
          let mid = (box.llx + box.urx) / 2.0
          box = { llx: mid - ROUTE_MIN_WIDTH / 2.0, lly: box.lly, urx: mid + ROUTE_MIN_WIDTH / 2.0, ury: box.ury }
        }
      }
      adjusted[i] = box
      i = i + 1
    }
  }
  let mut i = 0
  while i + 1 < adjusted.length() {
    if i >= fb && i <= lb && (i - fb) % 2 == 0 {
      let mut right = adjusted[i + 1]
      let left = adjusted[i]
      if left.llx + ROUTE_MIN_WIDTH > right.urx {
        right = { llx: right.llx, lly: right.lly, urx: left.llx + ROUTE_MIN_WIDTH, ury: right.ury }
      }
      if left.urx - ROUTE_MIN_WIDTH < right.llx {
        right = { llx: left.urx - ROUTE_MIN_WIDTH, lly: right.lly, urx: right.urx, ury: right.ury }
      }
      adjusted[i + 1] = right
    } else if i + 1 >= fb && i < lb && (i + 1 - fb) % 2 == 0 {
      let mut left = adjusted[i]
      let right = adjusted[i + 1]
      if left.llx + ROUTE_MIN_WIDTH > right.urx {
        left = { llx: right.urx - ROUTE_MIN_WIDTH, lly: left.lly, urx: left.urx, ury: left.ury }
      }
      if left.urx - ROUTE_MIN_WIDTH < right.llx {
        left = { llx: left.llx, lly: left.lly, urx: right.llx + ROUTE_MIN_WIDTH, ury: left.ury }
      }
      adjusted[i] = left
    }
    i = i + 1
  }
  adjusted
}

///|
pub fn edge_pathplan_polyline(
  edge : @cgraph.Edge,
  tail_name : String,
  head_name : String,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  rankdir : RankDir,
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  cluster_keys : Map[String, String],
  vnode_clusters : Map[String, String],
  cluster_bboxes : Map[String, @geom.Rect],
  x_groups : Map[Int, Array[String]],
  rank_y : Map[Int, Double],
  rank_ht1 : Map[Int, Double],
  rank_ht2 : Map[Int, Double],
  nodesep_pt : Double,
) -> (Array[@geom.Point], Array[(@geom.Point, @geom.Point)])? {
  let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
    Some(list) => list.copy()
    None => []
  }
  if vnodes.length() == 0 {
    return None
  }
  let tail_rank = match ranks.get(tail_name) {
    Some(value) => value
    None => return None
  }
  let head_rank = match ranks.get(head_name) {
    Some(value) => value
    None => return None
  }
  if tail_rank == head_rank {
    return None
  }
  let forward = tail_rank <= head_rank
  let swap_path = !forward
  let path_tail_name = if swap_path { head_name } else { tail_name }
  let path_head_name = if swap_path { tail_name } else { head_name }
  let path_tail_rank = if swap_path { head_rank } else { tail_rank }
  let path_head_rank = if swap_path { tail_rank } else { head_rank }
  let path_tail_anchor = if swap_path { head_anchor } else { tail_anchor }
  let path_head_anchor = if swap_path { tail_anchor } else { head_anchor }
  let path_tail_port = if swap_path { edge.head_port() } else { edge.tail_port() }
  let path_head_port = if swap_path { edge.tail_port() } else { edge.head_port() }
  let tail_cluster =
    cluster_key_for_name(path_tail_name, cluster_keys, vnode_clusters)
  let head_cluster =
    cluster_key_for_name(path_head_name, cluster_keys, vnode_clusters)
  let ordered = vnodes
  let merged_positions = merge_positions(positions, vnode_positions)
  let merged_sizes = merge_sizes(sizes, vnode_sizes)
  let route_sizes = pathplan_sizes(merged_sizes, vnode_sizes, nodesep_pt)
  let splinesep_pt = nodesep_pt / 4.0
  let (left_bound, right_bound) =
    compute_horizontal_bounds(merged_positions, route_sizes, nodesep_pt)
  let tail_boxes : Array[@geom.Rect] = []
  let head_boxes : Array[@geom.Rect] = []
  let path_boxes : Array[@geom.Rect] = []
  let tail_rank_y = match rank_y.get(path_tail_rank) {
    Some(value) => value
    None => path_tail_anchor.y
  }
  let tail_ht1 = match rank_ht1.get(path_tail_rank) {
    Some(value) => value
    None => 0.0
  }
  let head_rank_y = match rank_y.get(path_head_rank) {
    Some(value) => value
    None => path_head_anchor.y
  }
  let head_ht2 = match rank_ht2.get(path_head_rank) {
    Some(value) => value
    None => 0.0
  }
  let mut tail_box = match maximal_bbox_for_name(
    path_tail_name,
    path_tail_rank,
    merged_positions,
    route_sizes,
    vnode_sizes,
    cluster_keys,
    vnode_clusters,
    cluster_bboxes,
    x_groups,
    nodesep_pt,
    splinesep_pt,
    left_bound,
    right_bound,
    rank_ht1,
    rank_ht2,
    tail_cluster,
    head_cluster,
  ) {
    Some(box) => box
    None => return None
  }
  if !port_is_explicit(path_tail_port) {
    match rankdir {
      RankDir::TB | RankDir::BT =>
        tail_box = { llx: tail_box.llx, lly: tail_box.lly, urx: tail_box.urx, ury: path_tail_anchor.y }
      _ => ()
    }
  }
  tail_boxes.push(tail_box)
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let end_box = regular_end_box_bottom(tail_box, tail_rank_y - tail_ht1)
      if end_box.llx < end_box.urx && end_box.lly < end_box.ury {
        tail_boxes.push(end_box)
      }
    }
    _ => ()
  }
  let mut current_rank = path_tail_rank
  for vnode in ordered {
    let vnode_rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    match rank_gap_box(
      current_rank,
      vnode_rank,
      rank_y,
      rank_ht1,
      rank_ht2,
      left_bound,
      right_bound,
    ) {
      Some(box) => path_boxes.push(box)
      None => ()
    }
    match maximal_bbox_for_name(
      vnode,
      vnode_rank,
      merged_positions,
      route_sizes,
      vnode_sizes,
      cluster_keys,
      vnode_clusters,
      cluster_bboxes,
      x_groups,
      nodesep_pt,
      splinesep_pt,
      left_bound,
      right_bound,
      rank_ht1,
      rank_ht2,
      tail_cluster,
      head_cluster,
    ) {
      Some(box) => path_boxes.push(box)
      None => ()
    }
    current_rank = vnode_rank
  }
  match rank_gap_box(
    current_rank,
    path_head_rank,
    rank_y,
    rank_ht1,
    rank_ht2,
    left_bound,
    right_bound,
  ) {
    Some(box) => path_boxes.push(box)
    None => ()
  }
  let mut head_box = match maximal_bbox_for_name(
    path_head_name,
    path_head_rank,
    merged_positions,
    route_sizes,
    vnode_sizes,
    cluster_keys,
    vnode_clusters,
    cluster_bboxes,
    x_groups,
    nodesep_pt,
    splinesep_pt,
    left_bound,
    right_bound,
    rank_ht1,
    rank_ht2,
    tail_cluster,
    head_cluster,
  ) {
    Some(box) => box
    None => return None
  }
  if !port_is_explicit(path_head_port) {
    match rankdir {
      RankDir::TB | RankDir::BT =>
        head_box = { llx: head_box.llx, lly: path_head_anchor.y, urx: head_box.urx, ury: head_box.ury }
      _ => ()
    }
  }
  head_boxes.push(head_box)
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let end_box = regular_end_box_top(head_box, head_rank_y + head_ht2)
      if end_box.llx < end_box.urx && end_box.lly < end_box.ury {
        head_boxes.push(end_box)
      }
    }
    _ => ()
  }
  let boxes : Array[@geom.Rect] = []
  for box in tail_boxes {
    boxes.push(box)
  }
  for box in path_boxes {
    boxes.push(box)
  }
  let mut idx = head_boxes.length()
  while idx > 0 {
    idx = idx - 1
    boxes.push(head_boxes[idx])
  }
  let fb = tail_boxes.length() + 1
  let lb = fb + path_boxes.length() - 3
  if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
    let mut bi = 0
    for box in boxes {
      println(
        "  box[\{bi}] llx=\{box.llx} lly=\{box.lly} urx=\{box.urx} ury=\{box.ury}",
      )
      bi = bi + 1
    }
  }
  let adjusted_boxes = adjust_regular_path(boxes, fb, lb)
  let normalized_boxes = adjusted_boxes
  let route_start = path_tail_anchor
  let route_end = path_head_anchor
  let tail_explicit = port_is_explicit(path_tail_port)
  let head_explicit = port_is_explicit(path_head_port)
  match route_pathplan_from_boxes(
    normalized_boxes,
    route_start,
    route_end,
    rankdir,
    tail_explicit,
    head_explicit,
  ) {
    Some((points, polygon)) => {
      let out_points =
        if swap_path {
          let reversed : Array[@geom.Point] = []
          let mut idx = points.length()
          while idx > 0 {
            idx = idx - 1
            reversed.push(points[idx])
          }
          reversed
        } else {
          points
        }
      Some((out_points, polygon_edges(polygon)))
    }
    None => None
  }
}
