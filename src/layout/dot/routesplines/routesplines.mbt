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
fn rect(llx : Double, lly : Double, urx : Double, ury : Double) -> @geom.Rect {
  { llx, lly, urx, ury }
}

///|
const ROUTE_FUDGE : Double = 4.0

///|
const ROUTE_MIN_WIDTH : Double = 16.0

///|
const SIDE_BOTTOM : Int = 1
///|
const SIDE_RIGHT : Int = 2
///|
const SIDE_TOP : Int = 4
///|
const SIDE_LEFT : Int = 8

///|
pub struct PathAdjacency {
  out_edges : Map[String, Array[String]]
  in_edges : Map[String, Array[String]]
}

///|
pub fn build_path_adjacency(
  edges : Array[@cgraph.Edge],
  edge_vnodes : Map[String, Array[String]],
) -> PathAdjacency {
  let out_edges : Map[String, Array[String]] = Map::new()
  let in_edges : Map[String, Array[String]] = Map::new()
  for edge in edges {
    let key = edge_vnode_key(edge)
    let vnodes = match edge_vnodes.get(key) {
      Some(list) => list
      None => []
    }
    let path_nodes : Array[String] = []
    path_nodes.push(edge.tail().name())
    for name in vnodes {
      path_nodes.push(name)
    }
    path_nodes.push(edge.head().name())
    if path_nodes.length() < 2 {
      continue
    }
    let mut idx = 0
    while idx + 1 < path_nodes.length() {
      let tail = path_nodes[idx]
      let head = path_nodes[idx + 1]
      match out_edges.get(tail) {
        Some(list) => list.push(head)
        None => out_edges[tail] = [head]
      }
      match in_edges.get(head) {
        Some(list) => list.push(tail)
        None => in_edges[head] = [tail]
      }
      idx = idx + 1
    }
  }
  { out_edges, in_edges }
}

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
  x_groups : Map[Int, Array[String]],
) -> (Double, Double) {
  let mut min_rank : Int? = None
  let mut max_rank : Int? = None
  for rank, _ in x_groups {
    match min_rank {
      Some(value) => if rank < value { min_rank = Some(rank) }
      None => min_rank = Some(rank)
    }
    match max_rank {
      Some(value) => if rank > value { max_rank = Some(rank) }
      None => max_rank = Some(rank)
    }
  }
  let (start_rank, end_rank) = match (min_rank, max_rank) {
    (Some(start), Some(end)) => (start, end)
    _ => return (0.0, 0.0)
  }
  let mut left_bound = 0.0
  let mut right_bound = 0.0
  let mut seen = false
  let mut rank = start_rank
  while rank <= end_rank {
    match x_groups.get(rank) {
      Some(names) =>
        if names.length() > 0 {
        let left_name = names[0]
        let right_name = names[names.length() - 1]
        let left_pos = match positions.get(left_name) {
          Some(value) => value
          None => { rank = rank + 1; continue }
        }
        let right_pos = match positions.get(right_name) {
          Some(value) => value
          None => { rank = rank + 1; continue }
        }
        let left_size = size_for_name(left_name, sizes)
        let right_size = size_for_name(right_name, sizes)
        let left = left_pos.x - left_size.left_pt
        let right = right_pos.x + right_size.right_pt
        if !seen {
          left_bound = left
          right_bound = right
          seen = true
        } else {
          if left < left_bound {
            left_bound = left
          }
          if right > right_bound {
            right_bound = right
          }
        }
      }
      None => ()
    }
    left_bound = left_bound - ROUTE_MIN_WIDTH
    right_bound = right_bound + ROUTE_MIN_WIDTH
    rank = rank + 1
  }
  if !seen { (0.0, 0.0) } else { (left_bound, right_bound) }
}

///|
fn is_virtual_node(name : String, vnode_sizes : Map[String, NodeSize]) -> Bool {
  vnode_sizes.get(name) is Some(_)
}

///|
fn is_label_virtual(name : String, vnode_sizes : Map[String, NodeSize]) -> Bool {
  match vnode_sizes.get(name) {
    Some(size) => size.height_pt > 0.0
    None => false
  }
}

///|
fn order_for(name : String, order_index : Map[String, Int]) -> Int {
  match order_index.get(name) {
    Some(value) => value
    None => 0
  }
}

///|
fn pathscross(
  candidate : String,
  current : String,
  path_prev : String?,
  path_next : String?,
  out_edges : Map[String, Array[String]],
  in_edges : Map[String, Array[String]],
  order_index : Map[String, Int],
  vnode_sizes : Map[String, NodeSize],
) -> Bool {
  let out0 = match out_edges.get(candidate) {
    Some(list) => list
    None => []
  }
  let out1 = match out_edges.get(current) {
    Some(list) => list
    None => []
  }
  if out0.length() != 1 && out1.length() != 1 {
    return false
  }
  let order = order_for(candidate, order_index) > order_for(current, order_index)
  match path_next {
    Some(next) =>
      if out0.length() == 1 {
      let mut e0_head = out0[0]
      let mut e1_head = next
      let mut cnt = 0
      while cnt < 2 {
        if e0_head == e1_head {
          break
        }
        let order_head =
          order_for(e0_head, order_index) > order_for(e1_head, order_index)
        if order != order_head {
          return true
        }
        let e0_out = match out_edges.get(e0_head) {
          Some(list) => list
          None => []
        }
        if e0_out.length() != 1 || !is_virtual_node(e0_head, vnode_sizes) {
          break
        }
        let e1_out = match out_edges.get(e1_head) {
          Some(list) => list
          None => []
        }
        if e1_out.length() != 1 || !is_virtual_node(e1_head, vnode_sizes) {
          break
        }
        e0_head = e0_out[0]
        e1_head = e1_out[0]
        cnt = cnt + 1
      }
    }
    None => ()
  }
  let in0 = match in_edges.get(candidate) {
    Some(list) => list
    None => []
  }
  match path_prev {
    Some(prev) =>
      if in0.length() == 1 {
      let mut e0_tail = in0[0]
      let mut e1_tail = prev
      let mut cnt = 0
      while cnt < 2 {
        if e0_tail == e1_tail {
          break
        }
        let order_tail =
          order_for(e0_tail, order_index) > order_for(e1_tail, order_index)
        if order != order_tail {
          return true
        }
        let e0_in = match in_edges.get(e0_tail) {
          Some(list) => list
          None => []
        }
        if e0_in.length() != 1 || !is_virtual_node(e0_tail, vnode_sizes) {
          break
        }
        let e1_in = match in_edges.get(e1_tail) {
          Some(list) => list
          None => []
        }
        if e1_in.length() != 1 || !is_virtual_node(e1_tail, vnode_sizes) {
          break
        }
        e0_tail = e0_in[0]
        e1_tail = e1_in[0]
        cnt = cnt + 1
      }
    }
    None => ()
  }
  false
}

///|
fn neighbor_names_for_rank(
  name : String,
  rank : Int,
  x_groups : Map[Int, Array[String]],
  vnode_sizes : Map[String, NodeSize],
  out_edges : Map[String, Array[String]],
  in_edges : Map[String, Array[String]],
  order_index : Map[String, Int],
  path_prev : String?,
  path_next : String?,
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
            if is_label_virtual(candidate, vnode_sizes) {
              left = Some(candidate)
              break
            }
            if !is_virtual_node(candidate, vnode_sizes) {
              left = Some(candidate)
              break
            }
            if !pathscross(
              candidate,
              name,
              path_prev,
              path_next,
              out_edges,
              in_edges,
              order_index,
              vnode_sizes,
            ) {
              left = Some(candidate)
              break
            }
            left_idx = left_idx - 1
          }
          let mut right : String? = None
          let mut right_idx = idx + 1
          while right_idx < list.length() {
            let candidate = list[right_idx]
            if is_label_virtual(candidate, vnode_sizes) {
              right = Some(candidate)
              break
            }
            if !is_virtual_node(candidate, vnode_sizes) {
              right = Some(candidate)
              break
            }
            if !pathscross(
              candidate,
              name,
              path_prev,
              path_next,
              out_edges,
              in_edges,
              order_index,
              vnode_sizes,
            ) {
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
  out_edges : Map[String, Array[String]],
  in_edges : Map[String, Array[String]],
  order_index : Map[String, Int],
  path_prev : String?,
  path_next : String?,
) -> @geom.Rect? {
  let pos = match positions.get(name) {
    Some(value) => value
    None => return None
  }
  let size = size_for_name(name, sizes)
  let (left_neighbor, right_neighbor) =
    neighbor_names_for_rank(
      name,
      rank,
      x_groups,
      vnode_sizes,
      out_edges,
      in_edges,
      order_index,
      path_prev,
      path_next,
    )
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
fn beginpath_boxes_regular(
  base_box : @geom.Rect,
  node_pos : @geom.Point,
  node_size : NodeSize,
  start : @geom.Point,
  side : Int,
  ranksep_pt : Double,
) -> (Array[@geom.Rect], @geom.Point) {
  let boxes : Array[@geom.Rect] = []
  let mut start = start
  let node_top = node_pos.y + node_size.height_pt / 2.0
  let node_bottom = node_pos.y - node_size.height_pt / 2.0
  let node_left = node_pos.x - node_size.left_pt
  let node_right = node_pos.x + node_size.right_pt
  let fudge = 0.0
  if side != 0 {
    if (side & SIDE_TOP) != 0 {
      if start.x < node_pos.x {
        let b0 =
          rect(
            base_box.llx - 1.0,
            start.y,
            base_box.urx,
            node_top + ranksep_pt / 2.0,
          )
        let b =
          rect(
            base_box.llx - 1.0,
            node_bottom,
            node_left - fudge,
            start.y,
          )
        boxes.push(b0)
        boxes.push(b)
      } else {
        let b0 =
          rect(
            base_box.llx,
            start.y,
            base_box.urx + 1.0,
            node_top + ranksep_pt / 2.0,
          )
        let b =
          rect(
            node_right + fudge,
            node_bottom,
            base_box.urx + 1.0,
            start.y,
          )
        boxes.push(b0)
        boxes.push(b)
      }
      start = { x: start.x, y: start.y + 1.0 }
      return (boxes, start)
    } else if (side & SIDE_BOTTOM) != 0 {
      let b =
        rect(
          base_box.llx,
          base_box.lly,
          base_box.urx,
          max_double(base_box.ury, start.y),
        )
      boxes.push(b)
      start = { x: start.x, y: start.y - 1.0 }
      return (boxes, start)
    } else if (side & SIDE_LEFT) != 0 {
      let b = rect(base_box.llx, node_bottom, start.x, start.y)
      boxes.push(b)
      start = { x: start.x - 1.0, y: start.y }
      return (boxes, start)
    } else if (side & SIDE_RIGHT) != 0 {
      let b = rect(start.x, node_bottom, base_box.urx, start.y)
      boxes.push(b)
      start = { x: start.x + 1.0, y: start.y }
      return (boxes, start)
    }
  }
  let b = rect(base_box.llx, base_box.lly, base_box.urx, start.y)
  boxes.push(b)
  start = { x: start.x, y: start.y - 1.0 }
  (boxes, start)
}

///|
fn endpath_boxes_regular(
  base_box : @geom.Rect,
  node_pos : @geom.Point,
  node_size : NodeSize,
  end : @geom.Point,
  side : Int,
  ranksep_pt : Double,
) -> (Array[@geom.Rect], @geom.Point) {
  let boxes : Array[@geom.Rect] = []
  let mut end = end
  let node_top = node_pos.y + node_size.height_pt / 2.0
  let node_bottom = node_pos.y - node_size.height_pt / 2.0
  let node_left = node_pos.x - node_size.left_pt
  let node_right = node_pos.x + node_size.right_pt
  let fudge = 0.0
  if side != 0 {
    if (side & SIDE_TOP) != 0 {
      let b =
        rect(
          base_box.llx,
          min_double(base_box.lly, end.y),
          base_box.urx,
          base_box.ury,
        )
      boxes.push(b)
      end = { x: end.x, y: end.y + 1.0 }
      return (boxes, end)
    } else if (side & SIDE_BOTTOM) != 0 {
      if end.x < node_pos.x {
        let b0 =
          rect(
            base_box.llx - 1.0,
            node_bottom - ranksep_pt / 2.0,
            base_box.urx,
            end.y,
          )
        let b =
          rect(
            base_box.llx - 1.0,
            end.y,
            node_left - fudge,
            node_top,
          )
        boxes.push(b0)
        boxes.push(b)
      } else {
        let b0 =
          rect(
            base_box.llx,
            node_bottom - ranksep_pt / 2.0,
            base_box.urx + 1.0,
            end.y,
          )
        let b =
          rect(
            node_right + fudge,
            end.y,
            base_box.urx + 1.0,
            node_top,
          )
        boxes.push(b0)
        boxes.push(b)
      }
      end = { x: end.x, y: end.y - 1.0 }
      return (boxes, end)
    } else if (side & SIDE_LEFT) != 0 {
      let b = rect(base_box.llx, end.y, end.x, node_top)
      boxes.push(b)
      end = { x: end.x - 1.0, y: end.y }
      return (boxes, end)
    } else if (side & SIDE_RIGHT) != 0 {
      let b = rect(end.x, end.y, base_box.urx, node_top)
      boxes.push(b)
      end = { x: end.x + 1.0, y: end.y }
      return (boxes, end)
    }
  }
  let b = rect(base_box.llx, end.y, base_box.urx, base_box.ury)
  boxes.push(b)
  end = { x: end.x, y: end.y + 1.0 }
  (boxes, end)
}

///|
fn route_pathplan_from_boxes(
  boxes : Array[@geom.Rect],
  start : @geom.Point,
  end : @geom.Point,
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
  let path = @pathplan.shortest_path_in_poly(polygon, start, end)
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
  tail_port_side : Int,
  head_port_side : Int,
  ranksep_pt : Double,
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
  order_index : Map[String, Int],
  path_out_edges : Map[String, Array[String]],
  path_in_edges : Map[String, Array[String]],
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
  let path_tail_side = if swap_path { head_port_side } else { tail_port_side }
  let path_head_side = if swap_path { tail_port_side } else { head_port_side }
  let path_tail_pos = match positions.get(path_tail_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let path_head_pos = match positions.get(path_head_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let path_tail_size = size_for_name(path_tail_name, sizes)
  let path_head_size = size_for_name(path_head_name, sizes)
  if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
    println(
      "pathplan edge \{path_tail_name} -> \{path_head_name} tail_pos=\{path_tail_pos.x},\{path_tail_pos.y} head_pos=\{path_head_pos.x},\{path_head_pos.y} tail_anchor=\{path_tail_anchor.x},\{path_tail_anchor.y} head_anchor=\{path_head_anchor.x},\{path_head_anchor.y}",
    )
  }
  let tail_cluster =
    cluster_key_for_name(path_tail_name, cluster_keys, vnode_clusters)
  let head_cluster =
    cluster_key_for_name(path_head_name, cluster_keys, vnode_clusters)
  let ordered =
    if swap_path {
    let reversed : Array[String] = []
    let mut idx = vnodes.length()
    while idx > 0 {
      idx = idx - 1
      reversed.push(vnodes[idx])
    }
    reversed
  } else {
    vnodes
  }
  let merged_positions = merge_positions(positions, vnode_positions)
  let merged_sizes = merge_sizes(sizes, vnode_sizes)
  let route_sizes = pathplan_sizes(merged_sizes, vnode_sizes, nodesep_pt)
  let splinesep_pt = nodesep_pt / 4.0
  let (left_bound, right_bound) =
    compute_horizontal_bounds(merged_positions, route_sizes, x_groups)
  if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
    println("  pathplan bounds left=\{left_bound} right=\{right_bound}")
  }
  let tail_next =
    if ordered.length() > 0 { Some(ordered[0]) } else { Some(path_head_name) }
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
  let tail_box = match maximal_bbox_for_name(
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
    path_out_edges,
    path_in_edges,
    order_index,
    None,
    tail_next,
  ) {
    Some(box) => box
    None => return None
  }
  let (tail_boxes, route_start) = beginpath_boxes_regular(
    tail_box,
    path_tail_pos,
    path_tail_size,
    path_tail_anchor,
    path_tail_side,
    ranksep_pt,
  )
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let last_tail_box = tail_boxes[tail_boxes.length() - 1]
      let end_box = regular_end_box_bottom(last_tail_box, tail_rank_y - tail_ht1)
      if end_box.llx < end_box.urx && end_box.lly < end_box.ury {
        tail_boxes.push(end_box)
      }
    }
    _ => ()
  }
  let mut current_rank = path_tail_rank
  for i in 0..<ordered.length() {
    let vnode = ordered[i]
    let prev_node = if i == 0 { path_tail_name } else { ordered[i - 1] }
    let next_node =
      if i + 1 < ordered.length() { ordered[i + 1] } else { path_head_name }
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
      path_out_edges,
      path_in_edges,
      order_index,
      Some(prev_node),
      Some(next_node),
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
  let head_prev =
    if ordered.length() > 0 {
    Some(ordered[ordered.length() - 1])
  } else {
    Some(path_tail_name)
  }
  let head_box = match maximal_bbox_for_name(
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
    path_out_edges,
    path_in_edges,
    order_index,
    head_prev,
    None,
  ) {
    Some(box) => box
    None => return None
  }
  let (head_boxes, route_end) = endpath_boxes_regular(
    head_box,
    path_head_pos,
    path_head_size,
    path_head_anchor,
    path_head_side,
    ranksep_pt,
  )
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let last_head_box = head_boxes[head_boxes.length() - 1]
      let end_box = regular_end_box_top(last_head_box, head_rank_y + head_ht2)
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
  match route_pathplan_from_boxes(
    normalized_boxes,
    route_start,
    route_end,
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
