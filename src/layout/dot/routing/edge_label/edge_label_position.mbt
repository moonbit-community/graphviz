///|
/// Graphviz parity: flat-edge label midpoint offset helper aligned to
/// refs/graphviz/lib/dotgen/dotsplines.c (flat edge label placement).
/// Do not change behavior without updating fixtures/tests.
pub fn flat_edge_label_pos_simple(
  tail_port : @geom.Point,
  head_port : @geom.Point,
  tail_right_pt : Double,
  head_left_pt : Double,
  label_height_pt : Double,
  edge_label_flat_space_pt : Double,
) -> @geom.Point {
  let left_end = tail_port.x + tail_right_pt
  let right_end = head_port.x - head_left_pt
  let ctrx = (left_end + right_end) / 2.0
  let ctry = tail_port.y + (label_height_pt + edge_label_flat_space_pt) / 2.0
  @edge_spline.point(ctrx, ctry)
}

///|
/// Graphviz parity: label vnode offset aligned to refs/graphviz/lib/dotgen/dotsplines.c
/// (place_vnlabel, GD_flip).
/// Do not change behavior without updating fixtures/tests.
pub fn edge_label_pos_from_vnode(
  vnode_pos : @geom.Point,
  label_width_pt : Double,
  label_height_pt : Double,
  rankdir : @dot_shared.RankDir,
) -> @geom.Point {
  let width =
    if rankdir == @dot_shared.RankDir::LR || rankdir == @dot_shared.RankDir::RL {
      label_height_pt
    } else {
      label_width_pt
    }
  @edge_spline.point(vnode_pos.x + width / 2.0, vnode_pos.y)
}

///|
/// Graphviz parity: edge-label position from routed spline samples aligned to
/// refs/graphviz/lib/dotgen/dotsplines.c + lib/common/labels.c.
/// Do not change behavior without updating fixtures/tests.
pub fn edge_label_pos_from_input(
  input : EdgeLabelPosInput,
  edge_mid_label_metrics_for : (@cgraph.Edge) -> RouteLabelMetrics?,
  edge_label_pad_width_pt : Double,
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
      make_point_with_tangent(mid, tangent)
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
          @dot_shared.RankDir::LR | @dot_shared.RankDir::RL => @edge_spline.point(y_axis, x_axis)
          _ => @edge_spline.point(x_axis, y_axis)
        }
      (Some(value), None) =>
        match rankdir {
          @dot_shared.RankDir::LR | @dot_shared.RankDir::RL => @edge_spline.point(raw_pos.x, value)
          _ => @edge_spline.point(value, raw_pos.y)
        }
      _ => raw_pos
    }
  if @edge_semantics.edge_is_self(edge) {
    return Some(base_pos)
  }
  match label_rank_y {
    Some(_) =>
      match (edge_mid_label_metrics_for)(edge) {
        Some(metrics) => {
          let half_extent = match rankdir {
            @dot_shared.RankDir::LR | @dot_shared.RankDir::RL => metrics.height / 2.0
            _ => metrics.width / 2.0
          }
          let sign = match rankdir {
            @dot_shared.RankDir::RL => -1.0
            _ => 1.0
          }
          let mut pad = label_pad_boost
          if label_rank_x is None {
            if apply_label_pad {
              pad = pad + nodesep_pt * 0.22
            } else if metrics.width >= edge_label_pad_width_pt {
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
      let metrics = match (edge_mid_label_metrics_for)(edge) {
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
