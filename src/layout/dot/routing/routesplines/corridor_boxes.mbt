// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Routesplines corridor-box owner: rank-neighbor analysis, maximal node
/// boxes, rank gap boxes, and endpoint corridor construction.
priv struct RankNeighbors {
  left : String?
  right : String?
}

///|
priv struct EndpathResult {
  boxes : Array[@geom.Rect]
  endpoint : @geom.Point
}

///|
fn is_virtual_node(name : String, vnode_sizes : Map[String, NodeSize]) -> Bool {
  vnode_sizes.get(name) is Some(_)
}

///|

///|
/// Graphviz parity: label vnodes are virtual nodes with label height (> @node_primitives.VNODE_HEIGHT_PT).
fn is_label_virtual(name : String, vnode_sizes : Map[String, NodeSize]) -> Bool {
  match vnode_sizes.get(name) {
    Some(size) => size.height_pt > @node_primitives.VNODE_HEIGHT_PT
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
  let order = order_for(candidate, order_index) >
    order_for(current, order_index)
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
          let order_head = order_for(e0_head, order_index) >
            order_for(e1_head, order_index)
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
          let order_tail = order_for(e0_tail, order_index) >
            order_for(e1_tail, order_index)
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
) -> RankNeighbors {
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
                candidate, name, path_prev, path_next, out_edges, in_edges, order_index,
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
                candidate, name, path_prev, path_next, out_edges, in_edges, order_index,
                vnode_sizes,
              ) {
              right = Some(candidate)
              break
            }
            right_idx = right_idx + 1
          }
          return { left, right }
        }
        idx = idx + 1
      }
    }
    None => ()
  }
  { left: None, right: None }
}

///|
fn size_for_name(name : String, sizes : Map[String, NodeSize]) -> NodeSize {
  match sizes.get(name) {
    Some(value) => value
    None =>
      @node_primitives.node_size_from_points(
        @node_primitives.default_node_width_in() * 72.0,
        @node_primitives.default_node_height_in() * 72.0,
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
      pos.x >= rect.llx &&
      pos.x <= rect.urx &&
      pos.y >= rect.lly &&
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
  let rank_neighbors = neighbor_names_for_rank(
    name, rank, x_groups, vnode_sizes, out_edges, in_edges, order_index, path_prev,
    path_next,
  )
  let left_neighbor = rank_neighbors.left
  let right_neighbor = rank_neighbors.right
  let neighbor_sep = (neighbor : String, neighbor_size : NodeSize) => {
    let is_virtual = vnode_sizes.get(neighbor) is Some(_) ||
      neighbor_size.height_pt <= 0.0
    if is_virtual {
      splinesep_pt
    } else {
      nodesep_pt / 2.0
    }
  }
  let is_label_vnode = is_label_virtual(name, vnode_sizes)
  let mut b = pos.x - size.left_pt - ROUTE_FUDGE
  match left_neighbor {
    Some(neighbor) => {
      let neighbor_cluster = cluster_key_for_name(
        neighbor, cluster_keys, vnode_clusters,
      )
      let use_cluster = neighbor_cluster != "" &&
        neighbor_cluster != block_cluster_a &&
        neighbor_cluster != block_cluster_b &&
        (
          !is_virtual_node(neighbor, vnode_sizes) ||
          vnode_inside_cluster(
            neighbor, neighbor_cluster, positions, cluster_bboxes,
          )
        )
      if use_cluster {
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
            // Graphviz parity: left neighbor uses ND_mval (original right width),
            // even after recover_slack updates ND_rw.
            let neighbor_right = size_for_name(neighbor, mval_sizes).right_pt
            let nb = neighbor_pos.x +
              neighbor_right +
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
  let mut llx = @numeric.round_int(b).to_double()
  if left_neighbor is None {
    llx = min_double(llx, left_bound)
  }
  let mut br = if is_label_vnode {
    pos.x + ROUTE_LABEL_PAD
  } else {
    pos.x + size.right_pt + ROUTE_FUDGE
  }
  match right_neighbor {
    Some(neighbor) => {
      let neighbor_cluster = cluster_key_for_name(
        neighbor, cluster_keys, vnode_clusters,
      )
      let use_cluster = neighbor_cluster != "" &&
        neighbor_cluster != block_cluster_a &&
        neighbor_cluster != block_cluster_b &&
        (
          !is_virtual_node(neighbor, vnode_sizes) ||
          vnode_inside_cluster(
            neighbor, neighbor_cluster, positions, cluster_bboxes,
          )
        )
      if use_cluster {
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
            let nb = neighbor_pos.x -
              neighbor_size.left_pt -
              neighbor_sep(neighbor, neighbor_size)
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
  let mut urx = @numeric.round_int(br).to_double()
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
/// Graphviz parity: endpoint corridor construction aligned to refs/graphviz/lib/common/routespl.c.
/// Do not change behavior without updating fixtures/tests.
fn beginpath_boxes_regular(
  base_box : @geom.Rect,
  node_pos : @geom.Point,
  node_size : NodeSize,
  start : @geom.Point,
  side : Int,
  use_port_box : Bool,
  ranksep_pt : Double,
) -> EndpathResult {
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
        let b0 = rect(
          base_box.llx - 1.0,
          start.y,
          base_box.urx,
          node_top + ranksep_pt / 2.0,
        )
        let b = rect(
          base_box.llx - 1.0,
          node_bottom,
          node_left - fudge,
          start.y,
        )
        boxes.push(b0)
        boxes.push(b)
      } else {
        let b0 = rect(
          base_box.llx,
          start.y,
          base_box.urx + 1.0,
          node_top + ranksep_pt / 2.0,
        )
        let b = rect(
          node_right + fudge,
          node_bottom,
          base_box.urx + 1.0,
          start.y,
        )
        boxes.push(b0)
        boxes.push(b)
      }
      start = { x: start.x, y: start.y + 1.0 }
      return { boxes, endpoint: start }
    } else if (side & SIDE_BOTTOM) != 0 {
      let b = rect(
        base_box.llx,
        base_box.lly,
        base_box.urx,
        max_double(base_box.ury, start.y),
      )
      boxes.push(b)
      start = { x: start.x, y: start.y - 1.0 }
      return { boxes, endpoint: start }
    } else if (side & SIDE_LEFT) != 0 {
      let b = rect(base_box.llx, node_bottom, start.x, start.y)
      boxes.push(b)
      start = { x: start.x - 1.0, y: start.y }
      return { boxes, endpoint: start }
    } else if (side & SIDE_RIGHT) != 0 {
      let b = rect(start.x, node_bottom, base_box.urx, start.y)
      boxes.push(b)
      start = { x: start.x + 1.0, y: start.y }
      return { boxes, endpoint: start }
    }
  }
  if use_port_box {
    // Graphviz parity: pboxfn-supplied box skips default clamp/offset.
    boxes.push(base_box)
    return { boxes, endpoint: start }
  }
  // Graphviz parity: default to bottom side, clamp box to start.y, then offset by -1pt.
  let b = rect(base_box.llx, base_box.lly, base_box.urx, start.y)
  boxes.push(b)
  start = { x: start.x, y: start.y - 1.0 }
  { boxes, endpoint: start }
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
) -> EndpathResult {
  let boxes : Array[@geom.Rect] = []
  let mut end = end
  let node_top = node_pos.y + node_size.height_pt / 2.0
  let node_bottom = node_pos.y - node_size.height_pt / 2.0
  let node_left = node_pos.x - node_size.left_pt
  let node_right = node_pos.x + node_size.right_pt
  let fudge = 0.0
  if side != 0 {
    if (side & SIDE_TOP) != 0 {
      let b = rect(
        base_box.llx,
        min_double(base_box.lly, end.y),
        base_box.urx,
        base_box.ury,
      )
      boxes.push(b)
      end = { x: end.x, y: end.y + 1.0 }
      return { boxes, endpoint: end }
    } else if (side & SIDE_BOTTOM) != 0 {
      if end.x < node_pos.x {
        let b0 = rect(
          base_box.llx - 1.0,
          node_bottom - ranksep_pt / 2.0,
          base_box.urx,
          end.y,
        )
        let b = rect(base_box.llx - 1.0, end.y, node_left - fudge, node_top)
        boxes.push(b0)
        boxes.push(b)
      } else {
        let b0 = rect(
          base_box.llx,
          node_bottom - ranksep_pt / 2.0,
          base_box.urx + 1.0,
          end.y,
        )
        let b = rect(node_right + fudge, end.y, base_box.urx + 1.0, node_top)
        boxes.push(b0)
        boxes.push(b)
      }
      end = { x: end.x, y: end.y - 1.0 }
      return { boxes, endpoint: end }
    } else if (side & SIDE_LEFT) != 0 {
      let b = rect(base_box.llx, end.y, end.x, node_top)
      boxes.push(b)
      end = { x: end.x - 1.0, y: end.y }
      return { boxes, endpoint: end }
    } else if (side & SIDE_RIGHT) != 0 {
      let b = rect(end.x, end.y, base_box.urx, node_top)
      boxes.push(b)
      end = { x: end.x + 1.0, y: end.y }
      return { boxes, endpoint: end }
    }
  }
  if use_port_box {
    // Graphviz parity: pboxfn-supplied box skips default clamp/offset.
    boxes.push(base_box)
    return { boxes, endpoint: end }
  }
  // Graphviz parity: default to top side, clamp box to end.y, then offset by +1pt.
  let b = rect(base_box.llx, end.y, base_box.urx, base_box.ury)
  boxes.push(b)
  end = { x: end.x, y: end.y + 1.0 }
  { boxes, endpoint: end }
}
