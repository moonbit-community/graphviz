// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Anchor geometry domain for edge splines: compass vectors, exposed port
/// sides, and endpoint slope resolution for routed splines.
fn compass_angle(compass : @cgraph.Compass) -> Double? {
  match compass {
    @cgraph.Compass::N => Some(@math.PI * 0.5)
    @cgraph.Compass::NE => Some(@math.PI * 0.25)
    @cgraph.Compass::E => Some(0.0)
    @cgraph.Compass::SE => Some(-@math.PI * 0.25)
    @cgraph.Compass::S => Some(-@math.PI * 0.5)
    @cgraph.Compass::SW => Some(-@math.PI * 0.75)
    @cgraph.Compass::W => Some(@math.PI)
    @cgraph.Compass::NW => Some(@math.PI * 0.75)
    @cgraph.Compass::C => None
  }
}

///|
fn invflip_angle(angle : Double, rankdir : RankDir) -> Double {
  match rankdir {
    RankDir::TB => angle
    RankDir::BT => -angle
    RankDir::LR => angle - @math.PI * 0.5
    RankDir::RL =>
      if angle == @math.PI {
        -@math.PI * 0.5
      } else if angle == @math.PI * 0.75 {
        -@math.PI * 0.25
      } else if angle == @math.PI * 0.5 {
        0.0
      } else if angle == 0.0 {
        @math.PI * 0.5
      } else if angle == -@math.PI * 0.25 {
        @math.PI * 0.75
      } else if angle == -@math.PI * 0.5 {
        @math.PI
      } else {
        angle
      }
  }
}

///|
fn compass_vector(compass : @cgraph.Compass, rankdir : RankDir) -> @geom.Point? {
  match compass_angle(compass) {
    Some(angle) => {
      let theta = invflip_angle(angle, rankdir)
      Some(point(libm_cos(theta), libm_sin(theta)))
    }
    None => None
  }
}

///|
fn axis_direction(dir : @geom.Point) -> @geom.Point {
  let abs_dx = Double::abs(dir.x)
  let abs_dy = Double::abs(dir.y)
  if abs_dx <= 0.000001 && abs_dy <= 0.000001 {
    point(0.0, 0.0)
  } else if abs_dx >= abs_dy {
    let sign = if dir.x >= 0.0 { 1.0 } else { -1.0 }
    point(sign, 0.0)
  } else {
    let sign = if dir.y >= 0.0 { 1.0 } else { -1.0 }
    point(0.0, sign)
  }
}

///|
fn rotate_dir_for_rankdir(dir : @geom.Point, rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => dir
    RankDir::BT => point(dir.x, -dir.y)
    RankDir::LR => point(-dir.y, dir.x)
    RankDir::RL => point(dir.y, -dir.x)
  }
}

///|
fn port_side_direction(
  port_rect : @geom.Rect,
  anchor : @geom.Point,
  node_pos : @geom.Point,
  node_size : NodeSize,
  target : @geom.Point,
  rankdir : RankDir,
) -> @geom.Point? {
  let mid_x = (port_rect.llx + port_rect.urx) / 2.0
  let mid_y = (port_rect.lly + port_rect.ury) / 2.0
  let eps = if RECORD_BORDER_PT > 0.01 { RECORD_BORDER_PT + 0.01 } else { 0.01 }
  let node_rect = port_side_rect(node_pos, node_size)
  let candidates : Array[(@geom.Point, @geom.Point)] = []
  if Double::abs(port_rect.llx - node_rect.llx) <= eps {
    candidates.push((point(port_rect.llx, mid_y), point(-1.0, 0.0)))
  }
  if Double::abs(port_rect.urx - node_rect.urx) <= eps {
    candidates.push((point(port_rect.urx, mid_y), point(1.0, 0.0)))
  }
  if Double::abs(port_rect.lly - node_rect.lly) <= eps {
    candidates.push((point(mid_x, port_rect.lly), point(0.0, -1.0)))
  }
  if Double::abs(port_rect.ury - node_rect.ury) <= eps {
    candidates.push((point(mid_x, port_rect.ury), point(0.0, 1.0)))
  }
  if candidates.length() == 0 || candidates.length() == 4 {
    return None
  }
  let target_rel = point_sub(target, anchor)
  let target_rot = rotate_dir_for_rankdir(target_rel, rankdir)
  let mut best_dir = point(0.0, 0.0)
  let mut best_dist = 0.0
  let mut seen = false
  for pair in candidates {
    let (pos, dir) = pair
    let cand_rel = point_sub(pos, anchor)
    let cand_rot = rotate_dir_for_rankdir(cand_rel, rankdir)
    let dist = point_dist2(cand_rot, target_rot)
    if !seen || dist < best_dist {
      best_dist = dist
      best_dir = dir
      seen = true
    }
  }
  if seen {
    Some(best_dir)
  } else {
    None
  }
}

///|
pub fn port_side_rect(
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> @geom.Rect {
  let node_half_w = node_size.width_pt / 2.0
  let node_half_h = node_size.height_pt / 2.0
  {
    llx: node_pos.x - node_half_w,
    lly: node_pos.y - node_half_h,
    urx: node_pos.x + node_half_w,
    ury: node_pos.y + node_half_h,
  }
}

///|
pub fn port_side_count(
  port_rect : @geom.Rect,
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> Int {
  let eps = if RECORD_BORDER_PT > 0.01 { RECORD_BORDER_PT + 0.01 } else { 0.01 }
  let node_rect = port_side_rect(node_pos, node_size)
  let mut count = 0
  if Double::abs(port_rect.llx - node_rect.llx) <= eps {
    count = count + 1
  }
  if Double::abs(port_rect.urx - node_rect.urx) <= eps {
    count = count + 1
  }
  if Double::abs(port_rect.lly - node_rect.lly) <= eps {
    count = count + 1
  }
  if Double::abs(port_rect.ury - node_rect.ury) <= eps {
    count = count + 1
  }
  count
}

///|

///|
pub fn endpoint_slope_for_anchor(
  port : @cgraph.Port?,
  port_side : Int,
  anchor : @geom.Point,
  node_pos : @geom.Point,
  node_size : NodeSize,
  target : @geom.Point,
  rankdir : RankDir,
  tail : Bool,
  port_rect : @geom.Rect?,
) -> @geom.Point {
  if !@edge_identity.port_is_explicit(port) {
    return point(0.0, 0.0)
  }
  match port {
    Some(value) =>
      match value.compass {
        Some(compass) =>
          match compass_vector(compass, rankdir) {
            Some(vec) => if tail { vec } else { point(-vec.x, -vec.y) }
            None => point(0.0, 0.0)
          }
        None => {
          if port_side != 0 {
            let dir = if (port_side & PORT_SIDE_TOP) != 0 {
              point(0.0, 1.0)
            } else if (port_side & PORT_SIDE_BOTTOM) != 0 {
              point(0.0, -1.0)
            } else if (port_side & PORT_SIDE_LEFT) != 0 {
              point(-1.0, 0.0)
            } else if (port_side & PORT_SIDE_RIGHT) != 0 {
              point(1.0, 0.0)
            } else {
              point(0.0, 0.0)
            }
            return if tail { dir } else { point(-dir.x, -dir.y) }
          }
          match port_rect {
            Some(rect) =>
              match
                port_side_direction(
                  rect, anchor, node_pos, node_size, target, rankdir,
                ) {
                Some(dir) =>
                  return if tail { dir } else { point(-dir.x, -dir.y) }
                None => {
                  let side_count = port_side_count(rect, node_pos, node_size)
                  if side_count == 0 {
                    // Graphviz parity: dynamic ports with no exposed sides keep
                    // endpoint slopes unconstrained (routespl.c + shapes.c).
                    return point(0.0, 0.0)
                  }
                }
              }
            None => ()
          }
          let half_w = node_size.width_pt / 2.0
          let half_h = node_size.height_pt / 2.0
          let left = node_pos.x - half_w
          let right = node_pos.x + half_w
          let bottom = node_pos.y - half_h
          let top = node_pos.y + half_h
          let eps = 0.01
          let mut dir = point(0.0, 0.0)
          if anchor.x <= left + eps {
            dir = point(-1.0, 0.0)
          } else if anchor.x >= right - eps {
            dir = point(1.0, 0.0)
          } else if anchor.y <= bottom + eps {
            dir = point(0.0, -1.0)
          } else if anchor.y >= top - eps {
            dir = point(0.0, 1.0)
          } else {
            dir = axis_direction(point_sub(target, anchor))
          }
          if tail {
            dir
          } else {
            point(-dir.x, -dir.y)
          }
        }
      }
    None => point(0.0, 0.0)
  }
}
