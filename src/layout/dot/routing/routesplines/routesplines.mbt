// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Routesplines package entry: shared pathplan types/constants plus the
/// main polyline orchestration for regular edge routing.

///|
type NodeSize = @node_primitives.NodeSize

///|
type RankDir = @rankdir.RankDir

///|
fn min_double(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn max_double(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
fn rect(llx : Double, lly : Double, urx : Double, ury : Double) -> @geom.Rect {
  { llx, lly, urx, ury }
}

///|
const ROUTE_FUDGE : Double = 4.0

///|
const ROUTE_LABEL_PAD : Double = 10.0

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
fn straight_path_join_dir(rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => @edge_spline.point(0.0, -1.0)
    RankDir::BT => @edge_spline.point(0.0, 1.0)
    RankDir::LR => @edge_spline.point(1.0, 0.0)
    RankDir::RL => @edge_spline.point(-1.0, 0.0)
  }
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
priv struct PathplanCoreResult {
  points : Array[@geom.Point]
  barriers : Array[(@geom.Point, @geom.Point)]
  boxes : Array[@geom.Rect]
}

///|
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
  path_tail_prev : String?,
  path_head_next : String?,
  ordered : Array[String],
  vnode_ranks : Map[String, Int],
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
) -> PathplanCoreResult? {
  let tail_cluster = cluster_key_for_name(
    path_tail_name, cluster_keys, vnode_clusters,
  )
  let head_cluster = cluster_key_for_name(
    path_head_name, cluster_keys, vnode_clusters,
  )
  let tail_next = if ordered.length() > 0 {
    Some(ordered[0])
  } else {
    Some(path_head_name)
  }
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
  let tail_max_box = match
    maximal_bbox_for_name(
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
      path_tail_prev,
      tail_next,
    ) {
    Some(box) => box
    None => return None
  }
  let tail_box = match path_tail_port_box {
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
  let tail_endpath = beginpath_boxes_regular(
    tail_box, path_tail_pos, path_tail_size, path_tail_anchor, path_tail_side, use_tail_port_box,
    ranksep_pt,
  )
  let tail_boxes = tail_endpath.boxes
  let route_start = tail_endpath.endpoint
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let last_tail_box = tail_boxes[tail_boxes.length() - 1]
      let tail_gap_box : @geom.Rect = {
        llx: tail_max_box.llx,
        lly: last_tail_box.lly,
        urx: tail_max_box.urx,
        ury: last_tail_box.ury,
      }
      let end_box : @geom.Rect = {
        llx: tail_gap_box.llx,
        lly: tail_rank_y - tail_ht1,
        urx: tail_gap_box.urx,
        ury: tail_gap_box.lly,
      }
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
    let next_node = if i + 1 < ordered.length() {
      ordered[i + 1]
    } else {
      path_head_name
    }
    let vnode_rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    match
      rank_gap_box(
        current_rank, vnode_rank, rank_y, rank_ht1, rank_ht2, left_bound, right_bound,
      ) {
      Some(box) => path_boxes.push(box)
      None => ()
    }
    match
      maximal_bbox_for_name(
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
  match
    rank_gap_box(
      current_rank, path_head_rank, rank_y, rank_ht1, rank_ht2, left_bound, right_bound,
    ) {
    Some(box) => path_boxes.push(box)
    None => ()
  }
  let head_prev = if ordered.length() > 0 {
    Some(ordered[ordered.length() - 1])
  } else {
    Some(path_tail_name)
  }
  let head_max_box = match
    maximal_bbox_for_name(
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
      path_head_next,
    ) {
    Some(box) => box
    None => return None
  }
  let head_box = match path_head_port_box {
    Some(box) => if path_head_side == 0 { box } else { head_max_box }
    None => head_max_box
  }
  let head_endpath = endpath_boxes_regular(
    head_box, path_head_pos, path_head_size, path_head_anchor, path_head_side, use_head_port_box,
    ranksep_pt,
  )
  let head_boxes = head_endpath.boxes
  let route_end = head_endpath.endpoint
  match rankdir {
    RankDir::TB | RankDir::BT => {
      let last_head_box = head_boxes[head_boxes.length() - 1]
      let head_gap_box : @geom.Rect = {
        llx: head_max_box.llx,
        lly: last_head_box.lly,
        urx: head_max_box.urx,
        ury: last_head_box.ury,
      }
      let end_box : @geom.Rect = {
        llx: head_gap_box.llx,
        lly: head_gap_box.ury,
        urx: head_gap_box.urx,
        ury: head_rank_y + head_ht2,
      }
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
  let adjusted_boxes = adjust_regular_path(boxes, fb, lb)
  let normalized_boxes = adjusted_boxes
  match route_pathplan_from_boxes(normalized_boxes, route_start, route_end) {
    Some(route) =>
      Some({
        points: dedupe_polyline_points(route.points),
        barriers: polygon_edges(route.polygon),
        boxes: route.boxes,
      })
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
  merged_positions : Map[String, @geom.Point],
  route_sizes : Map[String, NodeSize],
  mval_route_sizes : Map[String, NodeSize],
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
  has_any_edge_label : Bool,
) -> PathplanResult? {
  let vnodes = match edge_vnodes.get(@edge_identity.edge_vnode_key(edge)) {
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
  let ordered = vnodes
  // Graphviz parity: Splinesep uses integer GD_nodesep / 4 (GD_nodesep is int).
  let splinesep_pt = (@numeric.round_int(nodesep_pt) / 4).to_double()
  let straight_eps = 0.01
  let label_threshold = if has_any_edge_label { 5 } else { 3 }
  let straight_len_from = (names : Array[String], start_idx : Int) => {
    if start_idx + 1 >= names.length() {
      0
    } else {
      match merged_positions.get(names[start_idx]) {
        Some(base) => {
          let mut count = 0
          let mut idx = start_idx + 1
          while idx < names.length() {
            let pos = match merged_positions.get(names[idx]) {
              Some(value) => value
              None => break
            }
            // Graphviz parity: straight_len checks x alignment in unflipped
            // coords; keep the small epsilon used by the original MoonBit
            // implementation because recovered vnode coordinates are not always
            // integer-identical to Graphviz at this stage.
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
  let first_split_for = (names : Array[String]) => {
    let mut split_start_idx = -1
    let mut split_straight_len = 0
    // Graphviz parity: straight-mode detection is evaluated while walking
    // the chain; a split can start at an interior vnode, not only the first.
    let mut start_idx = 0
    while start_idx + 1 < names.length() {
      let straight_len = straight_len_from(names, start_idx)
      if straight_len >= label_threshold {
        let sl = straight_len - 2
        if sl >= 1 {
          let seg1_head_idx = start_idx + 1
          let seg2_tail_idx = start_idx + straight_len - 1
          if seg1_head_idx < names.length() && seg2_tail_idx < names.length() {
            split_start_idx = start_idx
            split_straight_len = straight_len
          }
        }
        break
      }
      start_idx = start_idx + 1
    }
    if split_start_idx >= 0 {
      Some((split_start_idx, split_straight_len))
    } else {
      None
    }
  }
  if first_split_for(ordered) is Some(_) {
    // Graphviz parity: straight_path can split repeatedly on the remaining chain.
    let segments : Array[PathplanSegment] = []
    let mut current_tail_name = path_tail_name
    let mut current_tail_prev : String? = None
    let mut current_tail_anchor = path_tail_anchor
    let mut current_tail_side = path_tail_side
    let mut current_tail_port_box = path_tail_port_box
    let mut current_tail_rank = path_tail_rank
    let mut current_vnodes = ordered
    let mut split_failed = false
    while true {
      match first_split_for(current_vnodes) {
        Some((split_start_idx, split_straight_len)) => {
          let seg1_head_idx = split_start_idx + 1
          let seg2_tail_idx = split_start_idx + split_straight_len - 1
          if seg1_head_idx >= current_vnodes.length() ||
            seg2_tail_idx >= current_vnodes.length() {
            split_failed = true
            break
          }
          let seg1_head = current_vnodes[seg1_head_idx]
          let seg2_tail = current_vnodes[seg2_tail_idx]
          let seg1_head_next = if seg1_head_idx + 1 < current_vnodes.length() {
            Some(current_vnodes[seg1_head_idx + 1])
          } else {
            None
          }
          let seg2_tail_prev = if seg2_tail_idx > 0 {
            Some(current_vnodes[seg2_tail_idx - 1])
          } else {
            current_tail_prev
          }
          let seg1_core_vnodes : Array[String] = []
          let mut idx = 0
          while idx <= split_start_idx {
            seg1_core_vnodes.push(current_vnodes[idx])
            idx = idx + 1
          }
          let next_vnodes : Array[String] = []
          idx = seg2_tail_idx + 1
          while idx < current_vnodes.length() {
            next_vnodes.push(current_vnodes[idx])
            idx = idx + 1
          }
          let seg1_head_pos = match merged_positions.get(seg1_head) {
            Some(value) => value
            None => path_head_anchor
          }
          let seg2_tail_pos = match merged_positions.get(seg2_tail) {
            Some(value) => value
            None => current_tail_anchor
          }
          let seg1_head_rank = match vnode_ranks.get(seg1_head) {
            Some(value) => value
            None => path_head_rank
          }
          let seg2_tail_rank = match vnode_ranks.get(seg2_tail) {
            Some(value) => value
            None => current_tail_rank
          }
          // Graphviz parity: straight-chain split leaves virtual endpoints
          // unconstrained (beginpath/endpath ignore sides for virtual nodes).
          let seg1_head_side = 0
          match
            edge_pathplan_polyline_core(
              current_tail_name,
              seg1_head,
              current_tail_anchor,
              seg1_head_pos,
              current_tail_side,
              seg1_head_side,
              current_tail_port_box,
              None,
              current_tail_rank,
              seg1_head_rank,
              current_tail_prev,
              seg1_head_next,
              seg1_core_vnodes,
              vnode_ranks,
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
            Some(core_result) => {
              let recover_boxes = if current_tail_side == 0 &&
                core_result.points.length() >= 2 {
                let seg_raw = @edge_spline.edge_spline_raw_for_points(
                  core_result.points,
                  @edge_spline.point(0.0, 0.0),
                  straight_path_join_dir(rankdir),
                  false,
                  route_barriers=core_result.barriers,
                )
                if seg_raw.length() >= 4 {
                  limit_boxes_for_spline(
                    core_result.boxes,
                    seg_raw,
                    fallback_polyline=core_result.points,
                  )
                } else {
                  core_result.boxes
                }
              } else {
                core_result.boxes
              }
              let seg1_recover_vnodes : Array[String] = []
              // Graphviz parity: recover_slack runs later in the execution
              // stage; segment metadata here should stay geometry-only.
              let mut recover_idx = 0
              while recover_idx <= seg2_tail_idx {
                seg1_recover_vnodes.push(current_vnodes[recover_idx])
                recover_idx = recover_idx + 1
              }
              segments.push({
                points: core_result.points,
                barriers: core_result.barriers,
                boxes: recover_boxes,
                vnodes: seg1_recover_vnodes,
              })
            }
            None => {
              split_failed = true
              break
            }
          }
          current_tail_name = seg2_tail
          current_tail_prev = seg2_tail_prev
          current_tail_anchor = seg2_tail_pos
          current_tail_side = 0
          current_tail_port_box = None
          current_tail_rank = seg2_tail_rank
          current_vnodes = next_vnodes
        }
        None => {
          match
            edge_pathplan_polyline_core(
              current_tail_name, path_head_name, current_tail_anchor, path_head_anchor,
              current_tail_side, path_head_side, current_tail_port_box, path_head_port_box,
              current_tail_rank, path_head_rank, current_tail_prev, None, current_vnodes, vnode_ranks, vnode_sizes,
              cluster_keys, vnode_clusters,
              cluster_bboxes, x_groups, order_index, path_out_edges, path_in_edges,
              rank_y, rank_ht1, rank_ht2, nodesep_pt, ranksep_pt, rankdir,
              merged_positions, route_sizes, mval_route_sizes, splinesep_pt,
              left_bound, right_bound,
            ) {
            Some(core_result) => {
              let final_recover_vnodes : Array[String] = []
              for vnode in current_vnodes {
                final_recover_vnodes.push(vnode)
              }
              segments.push({
                points: core_result.points,
                barriers: core_result.barriers,
                boxes: core_result.boxes,
                vnodes: final_recover_vnodes,
              })
            }
            None => split_failed = true
          }
          break
        }
      }
    }
    if !split_failed && segments.length() > 0 {
      let combined : Array[@geom.Point] = []
      let all_barriers : Array[(@geom.Point, @geom.Point)] = []
      let all_boxes : Array[@geom.Rect] = []
      for segment in segments {
        if segment.points.length() > 0 {
          if combined.length() > 0 {
            // Graphviz parity: straight_path duplicates the last point twice.
            let last = combined[combined.length() - 1]
            combined.push(last)
            combined.push(last)
          }
          for point in segment.points {
            combined.push(point)
          }
        }
        for barrier in segment.barriers {
          all_barriers.push(barrier)
        }
        for box in segment.boxes {
          all_boxes.push(box)
        }
      }
      let out_points = if swap_path {
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
      return Some({
        points: out_points,
        barriers: all_barriers,
        boxes: all_boxes,
        segments,
      })
    }
  }
  match
    edge_pathplan_polyline_core(
      path_tail_name, path_head_name, path_tail_anchor, path_head_anchor, path_tail_side,
      path_head_side, path_tail_port_box, path_head_port_box, path_tail_rank, path_head_rank,
      None, None, ordered, vnode_ranks, vnode_sizes, cluster_keys, vnode_clusters, cluster_bboxes, x_groups,
      order_index, path_out_edges,
      path_in_edges, rank_y, rank_ht1, rank_ht2, nodesep_pt, ranksep_pt, rankdir,
      merged_positions, route_sizes, mval_route_sizes, splinesep_pt, left_bound,
      right_bound,
    ) {
    Some(core_result) => {
      let points = core_result.points
      let out_points = if swap_path {
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
        barriers: core_result.barriers,
        boxes: core_result.boxes,
        segments: [],
      })
    }
    None => None
  }
}
