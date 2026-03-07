///|
/// Port geometry, side-mask, and dynamic label-port anchor helpers for
/// record/html endpoint handling in dot layout.

type RankDir = @shared.RankDir
type NodeSize = @shared.NodeSize
type RecordPort = @record_geometry.RecordPort

///|
pub fn layout_port_offset(offset : @geom.Point, rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => offset
    RankDir::BT => { x: offset.x, y: -offset.y }
    RankDir::LR => { x: offset.y, y: -offset.x }
    RankDir::RL => { x: -offset.y, y: offset.x }
  }
}

///|
pub fn layout_ports_from_final(
  ports : Map[String, RecordPort],
  layout_pos : @geom.Point,
  rankdir : RankDir,
) -> Map[String, RecordPort] {
  let rotated : Map[String, RecordPort] = Map::new()
  for name, port in ports {
    let offset = layout_port_offset(port.center, rankdir)
    let center = @geom.Point::{
      x: layout_pos.x + offset.x,
      y: layout_pos.y + offset.y,
    }
    let size = match rankdir {
      RankDir::LR | RankDir::RL => @shared.swap_node_size(port.size)
      _ => port.size
    }
    rotated[name] = { center, size, sides: port.sides }
  }
  rotated
}

///|
pub const PORT_SIDE_BOTTOM : Int = 1
///|
pub const PORT_SIDE_RIGHT : Int = 2
///|
pub const PORT_SIDE_TOP : Int = 4
///|
pub const PORT_SIDE_LEFT : Int = 8
///|
pub const PORT_SIDE_ALL : Int =
  PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT | PORT_SIDE_TOP | PORT_SIDE_LEFT

///|
fn cvt_pt(p : @geom.Point, rankdir : RankDir) -> @geom.Point {
  match rankdir {
    RankDir::TB => p
    RankDir::BT => @edge_spline.point(p.x, -p.y)
    RankDir::LR => @edge_spline.point(-p.y, p.x)
    RankDir::RL => @edge_spline.point(p.y, p.x)
  }
}

///|
fn invflip_side(side : Int, rankdir : RankDir) -> Int {
  let mut out = 0
  let add = (from : Int, to : Int) => {
    if (side & from) != 0 {
      out = out | to
    }
  }
  match rankdir {
    RankDir::TB => side
    RankDir::BT => {
      add(PORT_SIDE_TOP, PORT_SIDE_BOTTOM)
      add(PORT_SIDE_BOTTOM, PORT_SIDE_TOP)
      add(PORT_SIDE_LEFT, PORT_SIDE_LEFT)
      add(PORT_SIDE_RIGHT, PORT_SIDE_RIGHT)
      out
    }
    RankDir::LR => {
      add(PORT_SIDE_TOP, PORT_SIDE_RIGHT)
      add(PORT_SIDE_BOTTOM, PORT_SIDE_LEFT)
      add(PORT_SIDE_LEFT, PORT_SIDE_TOP)
      add(PORT_SIDE_RIGHT, PORT_SIDE_BOTTOM)
      out
    }
    RankDir::RL => {
      add(PORT_SIDE_TOP, PORT_SIDE_RIGHT)
      add(PORT_SIDE_BOTTOM, PORT_SIDE_LEFT)
      add(PORT_SIDE_LEFT, PORT_SIDE_BOTTOM)
      add(PORT_SIDE_RIGHT, PORT_SIDE_TOP)
      out
    }
  }
}

///|
pub fn port_side_mask_from_rects(
  port_rect : @geom.Rect,
  node_rect : @geom.Rect,
) -> Int {
  let eps = if @record_geometry.RECORD_BORDER_PT > 0.01 {
    @record_geometry.RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let mut mask = 0
  if Double::abs(port_rect.llx - node_rect.llx) <= eps {
    mask = mask | PORT_SIDE_LEFT
  }
  if Double::abs(port_rect.urx - node_rect.urx) <= eps {
    mask = mask | PORT_SIDE_RIGHT
  }
  if Double::abs(port_rect.lly - node_rect.lly) <= eps {
    mask = mask | PORT_SIDE_BOTTOM
  }
  if Double::abs(port_rect.ury - node_rect.ury) <= eps {
    mask = mask | PORT_SIDE_TOP
  }
  mask
}

///|
priv struct DynamicPortAnchor {
  anchor : @geom.Point?
  side : Int
}

///|
priv struct ResolvedLabelPort {
  name : String?
  effective_compass : @cgraph.Compass?
}

///|
pub(all) struct DynamicPortAnchorForEdge {
  anchor : @geom.Point?
  side : Int
  is_dynamic : Bool
}

///|
fn resolve_dynamic_port_anchor(
  raw_port : RecordPort,
  node_pos : @geom.Point,
  other_pos : @geom.Point,
  rankdir : RankDir,
) -> DynamicPortAnchor {
  let sides = raw_port.sides
  if sides == 0 || sides == PORT_SIDE_ALL {
    return { anchor: None, side: 0 }
  }
  let half_w = raw_port.size.width_pt / 2.0
  let half_h = raw_port.size.height_pt / 2.0
  let port_rect : @geom.Rect = {
    llx: raw_port.center.x - half_w,
    lly: raw_port.center.y - half_h,
    urx: raw_port.center.x + half_w,
    ury: raw_port.center.y + half_h,
  }
  let mid_x = (port_rect.llx + port_rect.urx) / 2.0
  let mid_y = (port_rect.lly + port_rect.ury) / 2.0
  let pt = cvt_pt(node_pos, rankdir)
  let opt = cvt_pt(other_pos, rankdir)
  let mut best_side = 0
  let mut best_dist = 0.0
  let mut best_point = @edge_spline.point(0.0, 0.0)
  let mut seen = false
  let consider = (side : Int, pos : @geom.Point) => {
    if (sides & side) == 0 {
      return ()
    }
    let cand = @edge_spline.point_add(pt, pos)
    let dist = @edge_spline.point_dist2(cand, opt)
    if !seen || dist < best_dist {
      best_dist = dist
      best_side = side
      best_point = pos
      seen = true
    }
  }
  consider(PORT_SIDE_BOTTOM, @edge_spline.point(mid_x, port_rect.lly))
  consider(PORT_SIDE_RIGHT, @edge_spline.point(port_rect.urx, mid_y))
  consider(PORT_SIDE_TOP, @edge_spline.point(mid_x, port_rect.ury))
  consider(PORT_SIDE_LEFT, @edge_spline.point(port_rect.llx, mid_y))
  if !seen {
    return { anchor: None, side: 0 }
  }
  let offset = layout_port_offset(best_point, rankdir)
  let anchor = @edge_spline.point_add(node_pos, offset)
  { anchor: Some(anchor), side: invflip_side(best_side, rankdir) }
}

fn compass_port_name(compass : @cgraph.Compass) -> String {
  match compass {
    @cgraph.Compass::N => "n"
    @cgraph.Compass::NE => "ne"
    @cgraph.Compass::E => "e"
    @cgraph.Compass::SE => "se"
    @cgraph.Compass::S => "s"
    @cgraph.Compass::SW => "sw"
    @cgraph.Compass::W => "w"
    @cgraph.Compass::NW => "nw"
    @cgraph.Compass::C => "c"
  }
}

///|
/// Graphviz parity: `node:token` resolves to a label/record port first,
/// then falls back to compass semantics when no such port exists.
fn resolve_label_port_for_node(
  port : @cgraph.Port?,
  ports : Map[String, RecordPort],
) -> ResolvedLabelPort {
  match port {
    Some(value) =>
      match value.name {
        Some(name) =>
          if ports.get(name) is Some(_) {
            { name: Some(name), effective_compass: value.compass }
          } else {
            { name: None, effective_compass: value.compass }
          }
        None =>
          match value.compass {
            Some(compass) => {
              let fallback_name = compass_port_name(compass)
              if ports.get(fallback_name) is Some(_) {
                { name: Some(fallback_name), effective_compass: None }
              } else {
                { name: None, effective_compass: Some(compass) }
              }
            }
            None => { name: None, effective_compass: None }
          }
      }
    None => { name: None, effective_compass: None }
  }
}

///|
pub fn resolve_label_port_name(
  port : @cgraph.Port?,
  ports : Map[String, RecordPort],
) -> String? {
  let resolved_port = resolve_label_port_for_node(port, ports)
  resolved_port.name
}

///|
fn resolve_label_port_for_graph(
  node_name : String,
  port : @cgraph.Port?,
  label_ports_raw : Map[String, Map[String, RecordPort]],
) -> ResolvedLabelPort {
  match label_ports_raw.get(node_name) {
    Some(ports) => resolve_label_port_for_node(port, ports)
    None =>
      match port {
        Some(value) => { name: None, effective_compass: value.compass }
        None => { name: None, effective_compass: None }
      }
  }
}

///|
///|
pub fn dynamic_port_anchor_for_edge(
  port : @cgraph.Port?,
  node_name : String,
  raw_ports_map : Map[String, Map[String, RecordPort]],
  node_pos : @geom.Point,
  other_pos : @geom.Point,
  rankdir : RankDir,
  record_border_adjust : Double,
) -> DynamicPortAnchorForEdge {
  let resolved_port =
    resolve_label_port_for_graph(node_name, port, raw_ports_map)
  if resolved_port.effective_compass is Some(_) {
    return { anchor: None, side: 0, is_dynamic: false }
  }
  let port_name = match resolved_port.name {
    Some(value) => value
    None => return { anchor: None, side: 0, is_dynamic: false }
  }
  match raw_ports_map.get(node_name) {
    Some(raw_ports) =>
      match raw_ports.get(port_name) {
        Some(raw_port) => {
          let resolved_anchor =
            resolve_dynamic_port_anchor(
              raw_port,
              node_pos,
              other_pos,
              rankdir,
            )
          // Graphviz parity: keep resolvePort side in all rankdirs.
          // beginpath/endpath rely on this side to build record_path boxes.
          let effective_side = resolved_anchor.side
          // Graphviz parity: keep the raw dynamic anchor.
          // beginpath/endpath clamp start/end to box bounds in routespl.c,
          // and extra record-border shifts introduce 0.5pt drift in structs/records.
          let adjusted_anchor = resolved_anchor.anchor
          ignore(record_border_adjust)
          {
            anchor: adjusted_anchor,
            side: effective_side,
            is_dynamic: true,
          }
        }
        None => { anchor: None, side: 0, is_dynamic: false }
      }
    None => { anchor: None, side: 0, is_dynamic: false }
  }
}

///|
pub fn compass_side_mask(compass : @cgraph.Compass) -> Int {
  match compass {
    @cgraph.Compass::N => PORT_SIDE_TOP
    @cgraph.Compass::NE => PORT_SIDE_TOP | PORT_SIDE_RIGHT
    @cgraph.Compass::E => PORT_SIDE_RIGHT
    @cgraph.Compass::SE => PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT
    @cgraph.Compass::S => PORT_SIDE_BOTTOM
    @cgraph.Compass::SW => PORT_SIDE_BOTTOM | PORT_SIDE_LEFT
    @cgraph.Compass::W => PORT_SIDE_LEFT
    @cgraph.Compass::NW => PORT_SIDE_TOP | PORT_SIDE_LEFT
    @cgraph.Compass::C => 0
  }
}

///|
fn port_side_mask_from_rect(
  port_rect : @geom.Rect,
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> Int {
  let node_rect = @edge_spline.port_side_rect(node_pos, node_size)
  port_side_mask_from_rects(port_rect, node_rect)
}

///|
pub fn port_side_mask_from_anchor(
  anchor : @geom.Point,
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> Int {
  let eps = if @record_geometry.RECORD_BORDER_PT > 0.01 {
    @record_geometry.RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let node_rect = @edge_spline.port_side_rect(node_pos, node_size)
  if Double::abs(anchor.x - node_rect.llx) <= eps {
    return PORT_SIDE_LEFT
  }
  if Double::abs(anchor.x - node_rect.urx) <= eps {
    return PORT_SIDE_RIGHT
  }
  if Double::abs(anchor.y - node_rect.lly) <= eps {
    return PORT_SIDE_BOTTOM
  }
  if Double::abs(anchor.y - node_rect.ury) <= eps {
    return PORT_SIDE_TOP
  }
  0
}

///|
pub fn port_side_for_edge(
  port : @cgraph.Port?,
  port_rect : @geom.Rect?,
  node_pos : @geom.Point,
  node_size : NodeSize,
  side_anchor : @geom.Point?,
) -> Int {
  let all_sides =
    PORT_SIDE_BOTTOM | PORT_SIDE_RIGHT | PORT_SIDE_TOP | PORT_SIDE_LEFT
  let base_sides = match port_rect {
    Some(rect) => port_side_mask_from_rect(rect, node_pos, node_size)
    None => all_sides
  }
  match port {
    Some(value) =>
      match value.compass {
        Some(compass) => base_sides & compass_side_mask(compass)
        None =>
          match side_anchor {
            Some(anchor) => port_side_mask_from_anchor(anchor, node_pos, node_size)
            None => 0
          }
      }
    None => 0
  }
}

///|
pub fn port_rect_from_geometry(
  port : @cgraph.Port?,
  center : @geom.Point,
  size : NodeSize,
  node_size : NodeSize,
) -> @geom.Rect? {
  if !@edge_identity.port_is_explicit(port) {
    return None
  }
  let eps = if @record_geometry.RECORD_BORDER_PT > 0.01 {
    @record_geometry.RECORD_BORDER_PT + 0.01
  } else {
    0.01
  }
  let is_port_rect =
    Double::abs(size.width_pt - node_size.width_pt) > eps ||
      Double::abs(size.height_pt - node_size.height_pt) > eps
  if !is_port_rect {
    return None
  }
  let half_w = size.width_pt / 2.0
  let half_h = size.height_pt / 2.0
  Some({
    llx: center.x - half_w,
    lly: center.y - half_h,
    urx: center.x + half_w,
    ury: center.y + half_h,
  })
}

///|
pub fn port_geometry(
  node_name : String,
  port : @cgraph.Port?,
  label_ports_map : Map[String, Map[String, RecordPort]],
  node_pos : @geom.Point,
  node_size : NodeSize,
) -> PortGeometry {
  let resolved_port =
    resolve_label_port_for_graph(node_name, port, label_ports_map)
  let name = match resolved_port.name {
    Some(value) => value
    None => return { center: node_pos, size: node_size }
  }
  match label_ports_map.get(node_name) {
    Some(ports) =>
      match ports.get(name) {
        Some(port_info) => { center: port_info.center, size: port_info.size }
        None => { center: node_pos, size: node_size }
      }
    None => { center: node_pos, size: node_size }
  }
}

///|
pub(all) struct PortGeometry {
  center : @geom.Point
  size : NodeSize
}

///|
/// Graphviz parity: detect label ports using raw record/html port maps.
/// Do not change behavior without updating fixtures/tests.
pub fn port_is_label_port(
  node_name : String,
  port : @cgraph.Port?,
  label_ports_raw : Map[String, Map[String, RecordPort]],
) -> Bool {
  let resolved_port =
    resolve_label_port_for_graph(node_name, port, label_ports_raw)
  resolved_port.name is Some(_)
}
