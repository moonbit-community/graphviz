// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Shared geometry helpers for unranked engines: point parsing/scaling,
/// straight-line splines, and engine geometry context setup.
type NodeSize = @node_primitives.NodeSize

///|
type RecordOrientation = @layout_prep.RecordOrientation

///|
type RankDir = @rankdir.RankDir

///|
/// Shared point parsing/scaling and straight-line spline helpers used by
/// unranked layout assembly and fixed-position edge reuse.

///|
fn try_parse_double(text : String) -> Double? {
  try @string.parse_double(text) catch {
    _ => None
  } noraise {
    value => Some(value)
  }
}

///|
fn parse_numbers(text : String, limit : Int) -> Array[Double] {
  let numbers : Array[Double] = []
  let mut current = StringBuilder::new()
  let mut seen = false
  for ch in text {
    if ch.is_ascii_digit() ||
      ch == '-' ||
      ch == '+' ||
      ch == '.' ||
      ch == 'e' ||
      ch == 'E' {
      current.write_char(ch)
      seen = true
      continue
    }
    if seen {
      match try_parse_double(current.to_string()) {
        Some(value) => numbers.push(value)
        None => ()
      }
      if numbers.length() >= limit {
        return numbers
      }
      current = StringBuilder::new()
      seen = false
    }
  }
  if seen {
    match try_parse_double(current.to_string()) {
      Some(value) => numbers.push(value)
      None => ()
    }
  }
  numbers
}

///|
pub fn parse_point_attr(text : String) -> @geom.Point? {
  let numbers = parse_numbers(text, 2)
  if numbers.length() < 2 {
    None
  } else {
    Some({ x: numbers[0], y: numbers[1] })
  }
}

///|
pub fn scale_point(point : @geom.Point, factor : Double) -> @geom.Point {
  { x: point.x * factor, y: point.y * factor }
}

///|
fn line_control_points(
  start : @geom.Point,
  end : @geom.Point,
) -> Array[@geom.Point] {
  let control1 : @geom.Point = {
    x: (start.x * 2.0 + end.x) / 3.0,
    y: (start.y * 2.0 + end.y) / 3.0,
  }
  let control2 : @geom.Point = {
    x: (start.x + end.x * 2.0) / 3.0,
    y: (start.y + end.y * 2.0) / 3.0,
  }
  [start, control1, control2, end]
}

///|
fn line_spline(
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> @geom.Spline {
  let start = @node_primitives.clip_to_rect(tail_pos, tail_size, head_pos)
  let end = @node_primitives.clip_to_rect(head_pos, head_size, tail_pos)
  {
    start: Some(start),
    end: Some(end),
    points: line_control_points(start, end),
  }
}

///|
pub fn node_size_with_fallback(
  sizes : Map[String, NodeSize],
  node : @cgraph.Node,
  record_orientation : RecordOrientation,
) -> NodeSize {
  match sizes.get(node.name()) {
    Some(value) => value
    None => @node_geometry.node_size(node, record_orientation)
  }
}

///|
pub struct EngineGeometryContext {
  scale_factor : Double
  rankdir : RankDir
  record_orientation : RecordOrientation
}

///|
pub fn build_engine_geometry_context(
  graph : @cgraph.Graph,
  scale : Double,
) -> EngineGeometryContext {
  let scale_value = if scale <= 0.0 { 72.0 } else { scale }
  let scale_factor = 72.0 / scale_value
  let rankdir = @rankdir.graph_rankdir(graph)
  let record_orientation = @layout_prep.record_layout_orientation(rankdir)
  { scale_factor, rankdir, record_orientation }
}

///|
pub fn straight_line_edge_splines(
  _edge : @cgraph.Edge,
  tail_pos : @geom.Point,
  head_pos : @geom.Point,
  tail_size : NodeSize,
  head_size : NodeSize,
) -> Array[@geom.Spline] {
  [line_spline(tail_pos, head_pos, tail_size, head_size)]
}
