///|
type NodeSize = @dot_shared.NodeSize

///|
type RankDir = @dot_shared.RankDir

///|
/// Graphviz parity: route/splines aligned to refs/graphviz/lib/pathplan/*.c + common/routespl.c + common/splines.c + dotgen/dotsplines.c (fixtures).
/// Do not change behavior without updating fixtures/tests.
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
/// Graphviz parity: ROUND macro semantics (round half away from zero).
fn round_int(value : Double) -> Int {
  if value >= 0.0 {
    (value + 0.5).floor().to_int()
  } else {
    (value - 0.5).ceil().to_int()
  }
}

///|
const ROUTE_FUDGE : Double = 4.0

///|
const ROUTE_LABEL_PAD : Double = 10.0

///| Keep in sync with layout_base.VNODE_HEIGHT_PT.
const VNODE_HEIGHT_PT : Double = 1.0

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
/// Graphviz parity: path adjacency follows layout edge direction (after acyclic reversal).
/// Do not change behavior without updating fixtures/tests.
pub fn build_path_adjacency(
  edges : Array[@cgraph.Edge],
  edge_vnodes : Map[String, Array[String]],
  edge_tail : Array[String],
  edge_head : Array[String],
) -> PathAdjacency {
  let out_edges : Map[String, Array[String]] = Map::new()
  let in_edges : Map[String, Array[String]] = Map::new()
  let mut edge_idx = 0
  for edge in edges {
    let key = edge_vnode_key(edge)
    let vnodes = match edge_vnodes.get(key) {
      Some(list) => list
      None => []
    }
    let tail =
      if edge_idx < edge_tail.length() { edge_tail[edge_idx] } else {
        edge.tail().name()
      }
    let head =
      if edge_idx < edge_head.length() { edge_head[edge_idx] } else {
        edge.head().name()
      }
    let path_nodes : Array[String] = []
    path_nodes.push(tail)
    for name in vnodes {
      path_nodes.push(name)
    }
    path_nodes.push(head)
    if path_nodes.length() < 2 {
      edge_idx = edge_idx + 1
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
    edge_idx = edge_idx + 1
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
/// Graphviz parity: pathplan split metadata for straight-path routing.
pub(all) struct PathplanSegment {
  points : Array[@geom.Point]
  barriers : Array[(@geom.Point, @geom.Point)]
  boxes : Array[@geom.Rect]
  vnodes : Array[String]
}

///|
/// Graphviz parity: pathplan result for routesplines.
pub(all) struct PathplanResult {
  points : Array[@geom.Point]
  barriers : Array[(@geom.Point, @geom.Point)]
  boxes : Array[@geom.Rect]
  segments : Array[PathplanSegment]
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
        if left < left_bound {
          left_bound = left
        }
        if right > right_bound {
          right_bound = right
        }
      }
      None => ()
    }
    left_bound = left_bound - ROUTE_MIN_WIDTH
    right_bound = right_bound + ROUTE_MIN_WIDTH
    rank = rank + 1
  }
  (left_bound, right_bound)
}

///|
/// Graphviz parity: compute pathplan left/right bounds once (sd.LeftBound/RightBound).
/// Do not change behavior without updating fixtures/tests.
pub fn pathplan_bounds(
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  vnode_sizes : Map[String, NodeSize],
  x_groups : Map[Int, Array[String]],
) -> (Double, Double) {
  let merged_positions = merge_positions(positions, vnode_positions)
  let route_sizes = pathplan_sizes(sizes, vnode_sizes, 0.0)
  compute_horizontal_bounds(merged_positions, route_sizes, x_groups)
}

///|
fn is_virtual_node(name : String, vnode_sizes : Map[String, NodeSize]) -> Bool {
  vnode_sizes.get(name) is Some(_)
}

///|
///| Graphviz parity: label vnodes are virtual nodes with label height (> VNODE_HEIGHT_PT).
fn is_label_virtual(name : String, vnode_sizes : Map[String, NodeSize]) -> Bool {
  match vnode_sizes.get(name) {
    Some(size) => size.height_pt > VNODE_HEIGHT_PT
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
fn vnode_inside_cluster(
  name : String,
  cluster_key : String,
  positions : Map[String, @geom.Point],
  cluster_bboxes : Map[String, @geom.Rect],
) -> Bool {
  match (positions.get(name), cluster_bboxes.get(cluster_key)) {
    (Some(pos), Some(rect)) =>
      pos.x >= rect.llx && pos.x <= rect.urx && pos.y >= rect.lly &&
      pos.y <= rect.ury
    _ => false
  }
}

///|
/// Graphviz parity: maximal bbox bounds aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
fn maximal_bbox_for_name(
  name : String,
  rank : Int,
  positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  mval_sizes : Map[String, NodeSize],
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
  let vn_cluster = cluster_key_for_name(name, cluster_keys, vnode_clusters)
  let is_virtual = is_virtual_node(name, vnode_sizes)
  let block_cluster_a = if is_virtual { tail_cluster } else { vn_cluster }
  let block_cluster_b = if is_virtual { head_cluster } else { vn_cluster }
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
  let neighbor_sep = (neighbor : String, neighbor_size : NodeSize) => {
    let is_virtual =
      vnode_sizes.get(neighbor) is Some(_) || neighbor_size.height_pt <= 0.0
    if is_virtual { splinesep_pt } else { nodesep_pt / 2.0 }
  }
  let is_label_vnode = is_label_virtual(name, vnode_sizes)
  let mut b = pos.x - size.left_pt - ROUTE_FUDGE
  match left_neighbor {
    Some(neighbor) => {
      let neighbor_cluster =
        cluster_key_for_name(neighbor, cluster_keys, vnode_clusters)
      let use_cluster =
        neighbor_cluster != "" &&
          neighbor_cluster != block_cluster_a &&
          neighbor_cluster != block_cluster_b &&
          (!is_virtual_node(neighbor, vnode_sizes) ||
            vnode_inside_cluster(
              neighbor,
              neighbor_cluster,
              positions,
              cluster_bboxes,
            ))
      if use_cluster {
        match cluster_bboxes.get(neighbor_cluster) {
          Some(rect) => {
            let nb = rect.urx + splinesep_pt
            if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
              println(
                "  left_cluster \{name} -> \{neighbor} cluster=\{neighbor_cluster} rect=\{rect.llx},\{rect.lly},\{rect.urx},\{rect.ury} nb=\{nb}",
              )
            }
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
            // Graphviz parity: left neighbor uses ND_mval (original right width),
            // even after recover_slack updates ND_rw.
            let neighbor_right = size_for_name(neighbor, mval_sizes).right_pt
            let nb =
              neighbor_pos.x + neighbor_right +
              neighbor_sep(neighbor, neighbor_size)
            if nb < b {
              b = nb
            }
          }
          None => ()
        }
      }
    }
    None => ()
  }
  let mut llx = round_int(b).to_double()
  if left_neighbor is None {
    llx = min_double(llx, left_bound)
  }
  let mut br =
    if is_label_vnode { pos.x + ROUTE_LABEL_PAD } else { pos.x + size.right_pt + ROUTE_FUDGE }
  match right_neighbor {
    Some(neighbor) => {
      let neighbor_cluster =
        cluster_key_for_name(neighbor, cluster_keys, vnode_clusters)
      let use_cluster =
        neighbor_cluster != "" &&
          neighbor_cluster != block_cluster_a &&
          neighbor_cluster != block_cluster_b &&
          (!is_virtual_node(neighbor, vnode_sizes) ||
            vnode_inside_cluster(
              neighbor,
              neighbor_cluster,
              positions,
              cluster_bboxes,
            ))
      if use_cluster {
        match cluster_bboxes.get(neighbor_cluster) {
          Some(rect) => {
            let nb = rect.llx - splinesep_pt
            if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
              println(
                "  right_cluster \{name} -> \{neighbor} cluster=\{neighbor_cluster} rect=\{rect.llx},\{rect.lly},\{rect.urx},\{rect.ury} nb=\{nb}",
              )
            }
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
            let nb =
              neighbor_pos.x - neighbor_size.left_pt -
              neighbor_sep(neighbor, neighbor_size)
            if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
              println(
                "  right_neighbor \{name} -> \{neighbor} pos=\{neighbor_pos.x},\{neighbor_pos.y} left_pt=\{neighbor_size.left_pt} nb=\{nb}",
              )
            }
            if nb > br {
              br = nb
            }
          }
          None => ()
        }
      }
    }
    None => ()
  }
  let mut urx = round_int(br).to_double()
  if right_neighbor is None {
    urx = max_double(urx, right_bound)
  }
  if is_label_vnode {
    urx = urx - size.right_pt
    if urx < llx {
      urx = pos.x
    }
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
  if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
    let left_name = match left_neighbor {
      Some(value) => value
      None => "None"
    }
    let right_name = match right_neighbor {
      Some(value) => value
      None => "None"
    }
    println(
      "  node \{name} rank=\{rank} pos=\{pos.x},\{pos.y} size=\{size.left_pt},\{size.right_pt} left=\{left_name} right=\{right_name} box=\{llx},\{lly},\{urx},\{ury}",
    )
  }
  Some({ llx, lly, urx, ury })
}

///|
/// Graphviz parity: rank gap boxes mirror rank_box in refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
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
  Some({ llx, lly, urx, ury })
}

///|
///|
///|
/// Graphviz parity: polygon construction aligned to refs/graphviz/lib/common/routespl.c.
/// Do not change behavior without updating fixtures/tests.
fn boxes_to_polygon_points(boxes : Array[@geom.Rect]) -> Array[@geom.Point] {
  if boxes.length() == 0 {
    return []
  }
  let mut boxes = boxes
  // Graphviz parity: checkpath removes degenerate boxes before polygon build.
  if boxes.length() > 0 {
    let filtered : Array[@geom.Rect] = []
    for box in boxes {
      if Double::abs(box.lly - box.ury) < 0.01 {
        continue
      }
      if Double::abs(box.llx - box.urx) < 0.01 {
        continue
      }
      filtered.push(box)
    }
    boxes = filtered
    if boxes.length() == 0 {
      return []
    }
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
      // Graphviz parity: add full box loop when prev==next==-1 in reverse pass.
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
  use_port_box : Bool,
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
  if use_port_box {
    // Graphviz parity: pboxfn-supplied box skips default clamp/offset.
    boxes.push(base_box)
    return (boxes, start)
  }
  // Graphviz parity: default to bottom side, clamp box to start.y, then offset by -1pt.
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
  use_port_box : Bool,
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
  if use_port_box {
    // Graphviz parity: pboxfn-supplied box skips default clamp/offset.
    boxes.push(base_box)
    return (boxes, end)
  }
  // Graphviz parity: default to top side, clamp box to end.y, then offset by +1pt.
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
fn polyline_to_spline_points(
  points : Array[@geom.Point],
) -> Array[@geom.Point] {
  if points.length() < 2 {
    return []
  }
  let out : Array[@geom.Point] = []
  out.push(points[0])
  out.push(points[0])
  let mut i = 1
  while i + 1 < points.length() {
    let p = points[i]
    out.push(p)
    out.push(p)
    out.push(p)
    i = i + 1
  }
  let last = points[points.length() - 1]
  out.push(last)
  out.push(last)
  out
}

///|
/// Graphviz parity: limitBoxes sampling aligned to refs/graphviz/lib/common/routespl.c.
/// Do not change behavior without updating fixtures/tests.
fn limit_boxes_sample(
  boxes : Array[@geom.Rect],
  spline_points : Array[@geom.Point],
  delta : Double,
  fudge : Double,
) -> Unit {
  if boxes.length() == 0 || spline_points.length() < 4 {
    return ()
  }
  let num_div = delta * boxes.length().to_double()
  if num_div <= 0.0 {
    return ()
  }
  let mut spline_idx = 0
  while spline_idx + 3 < spline_points.length() {
    let p0 = spline_points[spline_idx]
    let p1 = spline_points[spline_idx + 1]
    let p2 = spline_points[spline_idx + 2]
    let p3 = spline_points[spline_idx + 3]
    let mut si = 0.0
    while si <= num_div {
      let t = si / num_div
      let mut x0 = p0.x
      let mut y0 = p0.y
      let mut x1 = p1.x
      let mut y1 = p1.y
      let mut x2 = p2.x
      let mut y2 = p2.y
      let x3 = p3.x
      let y3 = p3.y
      x0 = x0 + t * (x1 - x0)
      y0 = y0 + t * (y1 - y0)
      x1 = x1 + t * (x2 - x1)
      y1 = y1 + t * (y2 - y1)
      x2 = x2 + t * (x3 - x2)
      y2 = y2 + t * (y3 - y2)
      x0 = x0 + t * (x1 - x0)
      y0 = y0 + t * (y1 - y0)
      x1 = x1 + t * (x2 - x1)
      y1 = y1 + t * (y2 - y1)
      x0 = x0 + t * (x1 - x0)
      y0 = y0 + t * (y1 - y0)
      let mut bi = 0
      while bi < boxes.length() {
        let box = boxes[bi]
        if y0 <= box.ury + fudge && y0 >= box.lly - fudge {
          let llx = if x0 < box.llx { x0 } else { box.llx }
          let urx = if x0 > box.urx { x0 } else { box.urx }
          boxes[bi] = { llx, lly: box.lly, urx, ury: box.ury }
        }
        bi = bi + 1
      }
      si = si + 1.0
    }
    spline_idx = spline_idx + 3
  }
}

///|
/// Graphviz parity: box limiting loop aligned to refs/graphviz/lib/common/routespl.c.
/// Do not change behavior without updating fixtures/tests.
pub fn limit_boxes_for_spline(
  boxes : Array[@geom.Rect],
  spline_points : Array[@geom.Point],
  fallback_polyline? : Array[@geom.Point] = [],
) -> Array[@geom.Rect] {
  if boxes.length() == 0 {
    return boxes
  }
  let limited = boxes.copy()
  let initial_llx = 1.0e308
  let initial_urx = -1.0e308
  let mut i = 0
  while i < limited.length() {
    let box = limited[i]
    limited[i] = { llx: initial_llx, lly: box.lly, urx: initial_urx, ury: box.ury }
    i = i + 1
  }
  if spline_points.length() == 0 {
    return limited
  }
  let mut is_horizontal = true
  let mut is_vertical = true
  let base = spline_points[0]
  let fudge = 0.0001
  for point in spline_points {
    if Double::abs(base.y - point.y) > fudge {
      is_horizontal = false
    }
    if Double::abs(base.x - point.x) > fudge {
      is_vertical = false
    }
    if !is_horizontal && !is_vertical {
      break
    }
  }
  if is_horizontal || is_vertical {
    let x = base.x
    let mut idx = 0
    while idx < limited.length() {
      let box = limited[idx]
      limited[idx] = { llx: x, lly: box.lly, urx: x, ury: box.ury }
      idx = idx + 1
    }
    return limited
  }
  let mut delta = 10.0
  let mut unbounded = true
  let mut loopcnt = 0
  while unbounded && loopcnt < 15 {
    limit_boxes_sample(limited, spline_points, delta, fudge)
    unbounded = false
    for box in limited {
      if box.llx == initial_llx || box.urx == initial_urx {
        unbounded = true
        break
      }
    }
    if unbounded {
      delta = delta * 2.0
    }
    loopcnt = loopcnt + 1
  }
  if unbounded && fallback_polyline.length() >= 2 {
    let fallback_points = polyline_to_spline_points(fallback_polyline)
    limit_boxes_sample(limited, fallback_points, 10.0, fudge)
  }
  limited
}

///|
/// Graphviz parity: pathplan segment routing aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
fn edge_pathplan_polyline_core(
  path_tail_name : String,
  path_head_name : String,
  path_tail_anchor : @geom.Point,
  path_head_anchor : @geom.Point,
  path_tail_side : Int,
  path_head_side : Int,
  path_tail_port_box : @geom.Rect?,
  path_head_port_box : @geom.Rect?,
  path_tail_rank : Int,
  path_head_rank : Int,
  ordered : Array[String],
  positions : Map[String, @geom.Point],
  vnode_ranks : Map[String, Int],
  vnode_positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  mval_sizes : Map[String, NodeSize],
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
  ranksep_pt : Double,
  rankdir : RankDir,
  merged_positions : Map[String, @geom.Point],
  route_sizes : Map[String, NodeSize],
  mval_route_sizes : Map[String, NodeSize],
  splinesep_pt : Double,
  left_bound : Double,
  right_bound : Double,
) -> (Array[@geom.Point], Array[(@geom.Point, @geom.Point)], Array[@geom.Rect])? {
  let tail_cluster =
    cluster_key_for_name(path_tail_name, cluster_keys, vnode_clusters)
  let head_cluster =
    cluster_key_for_name(path_head_name, cluster_keys, vnode_clusters)
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
  let tail_max_box = match maximal_bbox_for_name(
    path_tail_name,
    path_tail_rank,
    merged_positions,
    route_sizes,
    mval_route_sizes,
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
  let tail_box =
    match path_tail_port_box {
      Some(box) => if path_tail_side == 0 { box } else { tail_max_box }
      None => tail_max_box
    }
  let path_tail_pos = match merged_positions.get(path_tail_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let path_head_pos = match merged_positions.get(path_head_name) {
    Some(value) => value
    None => { x: 0.0, y: 0.0 }
  }
  let path_tail_size = size_for_name(path_tail_name, mval_route_sizes)
  let path_head_size = size_for_name(path_head_name, mval_route_sizes)
  let use_tail_port_box = path_tail_port_box is Some(_) && path_tail_side == 0
  let use_head_port_box = path_head_port_box is Some(_) && path_head_side == 0
  let (tail_boxes, route_start) = beginpath_boxes_regular(
    tail_box,
    path_tail_pos,
    path_tail_size,
    path_tail_anchor,
    path_tail_side,
    use_tail_port_box,
    ranksep_pt,
  )
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let last_tail_box = tail_boxes[tail_boxes.length() - 1]
      let tail_gap_box : @geom.Rect = {
        llx: tail_max_box.llx,
        lly: last_tail_box.lly,
        urx: tail_max_box.urx,
        ury: last_tail_box.ury,
      }
      let end_box =
        regular_end_box_bottom(tail_gap_box, tail_rank_y - tail_ht1)
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
      mval_route_sizes,
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
  // Graphviz parity: insert rank gap box before the head (rank_box).
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
  let head_max_box = match maximal_bbox_for_name(
    path_head_name,
    path_head_rank,
    merged_positions,
    route_sizes,
    mval_route_sizes,
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
  let head_box =
    match path_head_port_box {
      Some(box) => if path_head_side == 0 { box } else { head_max_box }
      None => head_max_box
    }
  let (head_boxes, route_end) = endpath_boxes_regular(
    head_box,
    path_head_pos,
    path_head_size,
    path_head_anchor,
    path_head_side,
    use_head_port_box,
    ranksep_pt,
  )
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let last_head_box = head_boxes[head_boxes.length() - 1]
      let head_gap_box : @geom.Rect = {
        llx: head_max_box.llx,
        lly: last_head_box.lly,
        urx: head_max_box.urx,
        ury: last_head_box.ury,
      }
      let end_box =
        regular_end_box_top(head_gap_box, head_rank_y + head_ht2)
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
  // Graphviz parity: adjustregularpath uses vnode box list length (rank + node).
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
    Some((points, polygon)) =>
      Some((dedupe_polyline_points(points), polygon_edges(polygon), normalized_boxes))
    None => None
  }
}

///|
/// Graphviz parity: pathplan polyline construction aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_pathplan_polyline(
  edge : @cgraph.Edge,
  tail_name : String,
  head_name : String,
  tail_anchor : @geom.Point,
  head_anchor : @geom.Point,
  rankdir : RankDir,
  tail_port_side : Int,
  head_port_side : Int,
  tail_port_box : @geom.Rect?,
  head_port_box : @geom.Rect?,
  ranksep_pt : Double,
  ranks : Map[String, Int],
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  positions : Map[String, @geom.Point],
  vnode_positions : Map[String, @geom.Point],
  sizes : Map[String, NodeSize],
  mval_sizes : Map[String, NodeSize],
  vnode_mval_sizes : Map[String, NodeSize],
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
  left_bound : Double,
  right_bound : Double,
  has_edge_label : Bool,
) -> PathplanResult? {
  let vnodes = match edge_vnodes.get(edge_vnode_key(edge)) {
    Some(list) => list.copy()
    None => []
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
  let path_tail_port_box = if swap_path { head_port_box } else { tail_port_box }
  let path_head_port_box = if swap_path { tail_port_box } else { head_port_box }
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
  let ordered = vnodes
  let merged_positions = merge_positions(positions, vnode_positions)
  let route_sizes = pathplan_sizes(sizes, vnode_sizes, nodesep_pt)
  let mval_route_sizes = merge_sizes(mval_sizes, vnode_mval_sizes)
  // Graphviz parity: Splinesep uses integer GD_nodesep / 4 (GD_nodesep is int).
  let splinesep_pt = (round_int(nodesep_pt) / 4).to_double()
  if @sys.get_env_var("DOT_TRACE_PATHPLAN") is Some(_) {
    println("  pathplan bounds left=\{left_bound} right=\{right_bound}")
  }
  let straight_eps = 0.01
  let straight_len_from = (start_idx : Int) => {
    if start_idx + 1 >= ordered.length() {
      0
    } else {
      match vnode_positions.get(ordered[start_idx]) {
        Some(base) => {
          let mut count = 0
          let mut idx = start_idx + 1
          while idx < ordered.length() {
            let pos = match vnode_positions.get(ordered[idx]) {
              Some(value) => value
              None => break
            }
            // Graphviz parity: straight_len checks x alignment in unflipped coords.
            let aligned = Double::abs(pos.x - base.x) <= straight_eps
            if !aligned {
              break
            }
            count = count + 1
            idx = idx + 1
          }
          count
        }
        None => 0
      }
    }
  }
  let label_threshold = if has_edge_label { 5 } else { 3 }
  let mut split_head_idx = -1
  let mut split_tail_idx = -1
  // Graphviz parity: straight-mode detection is evaluated while walking
  // the chain; a split can start at an interior vnode, not only the first.
  let mut start_idx = 0
  while start_idx + 1 < ordered.length() {
    let straight_len = straight_len_from(start_idx)
    if straight_len >= label_threshold {
      let sl = straight_len - 2
      if sl >= 1 {
        let head_idx = start_idx + 1
        let tail_idx = head_idx + sl
        if tail_idx < ordered.length() {
          split_head_idx = head_idx
          split_tail_idx = tail_idx
        }
      }
      break
    }
    start_idx = start_idx + 1
  }
  if split_head_idx >= 0 && split_tail_idx >= split_head_idx {
    let seg1_head = ordered[split_head_idx]
    let seg2_tail = ordered[split_tail_idx]
    let seg1_vnodes : Array[String] = []
    let mut idx = 0
    while idx < split_head_idx {
      seg1_vnodes.push(ordered[idx])
      idx = idx + 1
    }
    let seg2_vnodes : Array[String] = []
    idx = split_tail_idx + 1
    while idx < ordered.length() {
      seg2_vnodes.push(ordered[idx])
      idx = idx + 1
    }
    let seg1_head_pos = match merged_positions.get(seg1_head) {
      Some(value) => value
      None => path_head_pos
    }
    let seg2_tail_pos = match merged_positions.get(seg2_tail) {
      Some(value) => value
      None => path_tail_pos
    }
    let seg1_head_rank = match vnode_ranks.get(seg1_head) {
      Some(value) => value
      None => path_head_rank
    }
    let seg2_tail_rank = match vnode_ranks.get(seg2_tail) {
      Some(value) => value
      None => path_tail_rank
    }
    let seg1_head_anchor = seg1_head_pos
    let seg2_tail_anchor = seg2_tail_pos
    // Graphviz parity: straight-chain split leaves virtual endpoints
    // unconstrained (beginpath/endpath ignore sides for virtual nodes).
    let seg1_head_side = 0
    let seg2_tail_side = 0
    let seg1 = edge_pathplan_polyline_core(
      path_tail_name,
      seg1_head,
      path_tail_anchor,
      seg1_head_anchor,
      path_tail_side,
      seg1_head_side,
      path_tail_port_box,
      None,
      path_tail_rank,
      seg1_head_rank,
      seg1_vnodes,
      positions,
      vnode_ranks,
      vnode_positions,
      sizes,
      mval_sizes,
      vnode_sizes,
      cluster_keys,
      vnode_clusters,
      cluster_bboxes,
      x_groups,
      order_index,
      path_out_edges,
      path_in_edges,
      rank_y,
      rank_ht1,
      rank_ht2,
      nodesep_pt,
      ranksep_pt,
      rankdir,
      merged_positions,
      route_sizes,
      mval_route_sizes,
      splinesep_pt,
      left_bound,
      right_bound,
    )
    let seg2 = edge_pathplan_polyline_core(
      seg2_tail,
      path_head_name,
      seg2_tail_anchor,
      path_head_anchor,
      seg2_tail_side,
      path_head_side,
      None,
      path_head_port_box,
      seg2_tail_rank,
      path_head_rank,
      seg2_vnodes,
      positions,
      vnode_ranks,
      vnode_positions,
      sizes,
      mval_sizes,
      vnode_sizes,
      cluster_keys,
      vnode_clusters,
      cluster_bboxes,
      x_groups,
      order_index,
      path_out_edges,
      path_in_edges,
      rank_y,
      rank_ht1,
      rank_ht2,
      nodesep_pt,
      ranksep_pt,
      rankdir,
      merged_positions,
      route_sizes,
      mval_route_sizes,
      splinesep_pt,
      left_bound,
      right_bound,
    )
    match (seg1, seg2) {
      (Some((points1, barriers1, boxes1)), Some((points2, barriers2, boxes2))) => {
        let combined : Array[@geom.Point] = []
        for p in points1 {
          combined.push(p)
        }
        if points2.length() > 0 {
          if combined.length() > 0 {
            // Graphviz parity: straight_path duplicates the last point twice.
            let last = combined[combined.length() - 1]
            combined.push(last)
            combined.push(last)
          }
          let mut pi = 0
          while pi < points2.length() {
            combined.push(points2[pi])
            pi = pi + 1
          }
        }
        let all_barriers : Array[(@geom.Point, @geom.Point)] = []
        for entry in barriers1 {
          all_barriers.push(entry)
        }
        for entry in barriers2 {
          all_barriers.push(entry)
        }
        let all_boxes : Array[@geom.Rect] = []
        for box in boxes1 {
          all_boxes.push(box)
        }
        for box in boxes2 {
          all_boxes.push(box)
        }
        let out_points =
          if swap_path {
            let reversed : Array[@geom.Point] = []
            let mut idx = combined.length()
            while idx > 0 {
              idx = idx - 1
              reversed.push(combined[idx])
            }
            reversed
          } else {
            combined
          }
        let segments : Array[PathplanSegment] = [
          {
            points: points1,
            barriers: barriers1,
            boxes: boxes1,
            vnodes: seg1_vnodes,
          },
          {
            points: points2,
            barriers: barriers2,
            boxes: boxes2,
            vnodes: seg2_vnodes,
          },
        ]
        return Some({
          points: out_points,
          barriers: all_barriers,
          boxes: all_boxes,
          segments,
        })
      }
      _ => ()
    }
  }
  match edge_pathplan_polyline_core(
    path_tail_name,
    path_head_name,
    path_tail_anchor,
    path_head_anchor,
    path_tail_side,
    path_head_side,
    path_tail_port_box,
    path_head_port_box,
    path_tail_rank,
    path_head_rank,
    ordered,
    positions,
    vnode_ranks,
    vnode_positions,
    sizes,
    mval_sizes,
    vnode_sizes,
    cluster_keys,
    vnode_clusters,
    cluster_bboxes,
    x_groups,
    order_index,
    path_out_edges,
    path_in_edges,
    rank_y,
    rank_ht1,
    rank_ht2,
    nodesep_pt,
    ranksep_pt,
    rankdir,
    merged_positions,
    route_sizes,
    mval_route_sizes,
    splinesep_pt,
    left_bound,
    right_bound,
  ) {
    Some((points, barriers, boxes)) => {
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
      Some({
        points: out_points,
        barriers,
        boxes,
        segments: [],
      })
    }
    None => None
  }
}
