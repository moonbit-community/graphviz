///|
/// Edge-label rank/vnode helpers aligned with Graphviz dotsplines label flows.

///|
priv struct EdgeLabelEntry {
  key : String
  pos : @geom.Point
  base_axis : Double
  half_axis : Double
}

///|
priv struct AdjustedEdgeLabels {
  edges : Array[DotLayoutEdge]
  updates : Map[String, @geom.Point]
}

///|
fn edge_label_rank_info(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
) -> EdgeLabelRankInfo? {
  if edge_mid_label_width_pt(edge) <= 0.0 {
    return None
  }
  let tail_rank = match ranks.get(edge.tail().name()) {
    Some(value) => value
    None => return None
  }
  let head_rank = match ranks.get(edge.head().name()) {
    Some(value) => value
    None => return None
  }
  let min_rank = if tail_rank < head_rank { tail_rank } else { head_rank }
  let max_rank = if tail_rank < head_rank { head_rank } else { tail_rank }
  let span = max_rank - min_rank
  if span <= 1 {
    return None
  }
  let label_rank = (min_rank + max_rank) / 2
  Some({ label_rank, span })
}

///|
fn edge_label_rank_y(
  edge : @cgraph.Edge,
  ranks : Map[String, Int],
  rank_y : Map[Int, Double],
) -> Double? {
  match edge_label_rank_info(edge, ranks) {
    Some(info) => rank_y.get(info.label_rank)
    None => None
  }
}

///|
fn edge_label_rank_x(
  edge : @cgraph.Edge,
  label_rank : Int,
  vnode_ranks : Map[String, Int],
  edge_vnodes : Map[String, Array[String]],
  vnode_positions : Map[String, @geom.Point],
) -> Double? {
  match edge_vnodes.get(@dot_shared.edge_vnode_key(edge)) {
    Some(vnodes) =>
      for name in vnodes {
        match vnode_ranks.get(name) {
          Some(rank) =>
            if rank == label_rank {
              match vnode_positions.get(name) {
                Some(pos) => return Some(pos.x)
                None => ()
              }
            }
          None => ()
        }
      }
    None => ()
  }
  None
}

///|
/// Graphviz parity: label vnode offset aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// (place_vnlabel, GD_flip).
/// Do not change behavior without updating fixtures/tests.
fn edge_label_pos_from_vnode(
  vnode_pos : @geom.Point,
  label_width_pt : Double,
  label_height_pt : Double,
  rankdir : RankDir,
) -> @geom.Point {
  let width =
    if rankdir == RankDir::LR || rankdir == RankDir::RL {
      label_height_pt
    } else {
      label_width_pt
    }
  @edge_spline.point(vnode_pos.x + width / 2.0, vnode_pos.y)
}

///|
fn vnode_is_merged(
  name : String,
  adjacency : @routesplines.PathAdjacency,
) -> Bool {
  let out_raw = match adjacency.out_edges.get(name) {
    Some(list) => list
    None => []
  }
  let in_raw = match adjacency.in_edges.get(name) {
    Some(list) => list
    None => []
  }
  let unique_count = (list : Array[String]) => {
    let seen : Map[String, Bool] = Map::new()
    let mut count = 0
    for item in list {
      if seen.get(item) is None {
        seen[item] = true
        count = count + 1
      }
    }
    count
  }
  // Graphviz virtual edges can carry parallel multiplicity on one edge record.
  // Our path adjacency lists parallel hops explicitly, so merge detection must
  // compare distinct predecessors/successors instead of raw multiplicity.
  let out_count = unique_count(out_raw)
  let in_count = unique_count(in_raw)
  out_count > 1 || in_count > 1
}

///|
/// Graphviz parity: recover_slack aligned to refs/graphviz/lib/dotgen/dotsplines.c.
/// Do not change behavior without updating fixtures/tests.
fn recover_slack_vnodes(
  input : @routing.RecoverSlackVnodesInput,
) -> Unit {
  let edge = input.edge
  let ordered_vnodes = input.ordered_vnodes
  let boxes = input.boxes
  let ranks = input.ranks
  let vnode_ranks = input.vnode_ranks
  let rank_y = input.rank_y
  let vnode_positions = input.vnode_positions
  let vnode_sizes = input.vnode_sizes
  let adjacency = input.adjacency
  if ordered_vnodes.length() == 0 || boxes.length() == 0 {
    return ()
  }
  let label_rank = match edge_label_rank_info(edge, ranks) {
    Some(info) => info.label_rank
    None => -1
  }
  let mut box_idx = 0
  for vnode in ordered_vnodes {
    if vnode_is_merged(vnode, adjacency) {
      break
    }
    let vnode_rank = match vnode_ranks.get(vnode) {
      Some(value) => value
      None => continue
    }
    let vnode_y = match rank_y.get(vnode_rank) {
      Some(value) => value
      None => continue
    }
    while box_idx < boxes.length() && boxes[box_idx].lly > vnode_y {
      box_idx = box_idx + 1
    }
    if box_idx >= boxes.length() {
      break
    }
    let box = boxes[box_idx]
    if box.ury < vnode_y {
      continue
    }
    let size = match vnode_sizes.get(vnode) {
      Some(value) => value
      None => continue
    }
    if vnode_rank == label_rank {
      let new_x = box.urx
      let left = new_x - box.llx
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        vnode_size_from_widths_with_h(left, size.right_pt, size.height_pt)
    } else {
      let new_x = (box.llx + box.urx) / 2.0
      let half = (box.urx - box.llx) / 2.0
      vnode_positions[vnode] = { x: new_x, y: vnode_y }
      vnode_sizes[vnode] =
        vnode_size_from_widths_with_h(half, half, size.height_pt)
    }
  }
}

///|
fn flat_edge_label_pos_simple(
  tail_port : @geom.Point,
  head_port : @geom.Point,
  tail_right_pt : Double,
  head_left_pt : Double,
  label_height_pt : Double,
) -> @geom.Point {
  let left_end = tail_port.x + tail_right_pt
  let right_end = head_port.x - head_left_pt
  let ctrx = (left_end + right_end) / 2.0
  let ctry = tail_port.y + (label_height_pt + EDGE_LABEL_FLAT_SPACE_PT) / 2.0
  @edge_spline.point(ctrx, ctry)
}

///|
fn edge_label_pos_from_input(
  input : @routing.EdgeLabelPosInput,
) -> @geom.Point? {
  let edge = input.edge
  let spline = input.spline
  let tail_clip = input.tail_clip
  let head_clip = input.head_clip
  let rankdir = input.rankdir
  let label_rank_y = input.label_rank_y
  let label_rank_x = input.label_rank_x
  let apply_label_pad = input.apply_label_pad
  let nodesep_pt = input.nodesep_pt
  let label_pad_boost = input.label_pad_boost
  let samples = sample_spline_points(spline.points, 96)
  let fallback = match spline_label_pos_with_samples(samples) {
    Some(value) => value
    None => {
      let mid = @edge_spline.point(
        (tail_clip.x + head_clip.x) / 2.0,
        (tail_clip.y + head_clip.y) / 2.0,
      )
      let delta = @edge_spline.point_sub(head_clip, tail_clip)
      let len = Double::sqrt(delta.x * delta.x + delta.y * delta.y)
      let tangent =
        if len <= 0.0 { @edge_spline.point(1.0, 0.0) } else { @edge_spline.point_scale(delta, 1.0 / len) }
      { pos: mid, tangent }
    }
  }
  let label_point = match label_rank_y {
    Some(axis) =>
      match spline_label_pos_at_samples(
        samples,
        axis,
        false,
      ) {
        Some(value) => value
        None => fallback
      }
    None => fallback
  }
  let raw_pos = label_point.pos
  let dir = label_point.tangent
  let base_pos =
    match (label_rank_x, label_rank_y) {
      (Some(x_axis), Some(y_axis)) =>
        match rankdir {
          RankDir::LR | RankDir::RL => @edge_spline.point(y_axis, x_axis)
          _ => @edge_spline.point(x_axis, y_axis)
        }
      (Some(value), None) =>
        match rankdir {
          RankDir::LR | RankDir::RL => @edge_spline.point(raw_pos.x, value)
          _ => @edge_spline.point(value, raw_pos.y)
        }
      _ => raw_pos
    }
  if @dot_shared.edge_is_self(edge) {
    return Some(base_pos)
  }
  match label_rank_y {
    Some(_) =>
      match edge_mid_label_metrics(edge) {
        Some(metrics) => {
          let half_extent = match rankdir {
            RankDir::LR | RankDir::RL => metrics.height / 2.0
            _ => metrics.width / 2.0
          }
          let sign = match rankdir {
            RankDir::RL => -1.0
            _ => 1.0
          }
          let mut pad = label_pad_boost
          if label_rank_x is None {
            if apply_label_pad {
              pad = pad + nodesep_pt * 0.22
            } else if metrics.width >= EDGE_LABEL_PAD_WIDTH_PT {
              pad = pad + nodesep_pt * 0.22
            }
          } else {
            pad = 0.0
          }
          Some(@edge_spline.point(base_pos.x + sign * (half_extent + pad), base_pos.y))
        }
        None => Some(base_pos)
      }
    None => {
      let metrics = match edge_mid_label_metrics(edge) {
        Some(value) => value
        None => return Some(base_pos)
      }
      let normal = @edge_spline.point(-dir.y, dir.x)
      let axis_threshold = 0.1
      let abs_dx = Double::abs(dir.x)
      let abs_dy = Double::abs(dir.y)
      if spline.points.length() > 4 &&
        abs_dx > axis_threshold &&
        abs_dy > axis_threshold {
        return Some(base_pos)
      }
      let offset =
        if abs_dx <= axis_threshold {
          metrics.width / 2.0
        } else if abs_dy <= axis_threshold {
          metrics.height / 2.0
        } else {
          0.0
        }
      if offset <= 0.0 {
        Some(base_pos)
      } else {
        let pad = label_pad_boost
        Some(@edge_spline.point_add(base_pos, @edge_spline.point_scale(normal, offset + pad)))
      }
    }
  }
}

///|
fn edge_label_pos(
  input : @routing.EdgeLabelPosInput,
) -> @geom.Point? {
  edge_label_pos_from_input(input)
}
