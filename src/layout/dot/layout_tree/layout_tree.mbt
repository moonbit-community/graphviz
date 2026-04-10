// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Internal layout output types used by tree-heavy dot subpackages so they can
/// work with one cohesive layout payload.

///|
/// Node layout output.
/// pos is in points; width/height are in inches.
pub(all) struct DotLayoutNode {
  node : @cgraph.Node
  pos : @geom.Point
  width_in : Double
  height_in : Double
  label_pos : @geom.Point?
  xlabel_pos : @geom.Point?
}

///|
/// Edge layout output.
/// Splines use points in points; label positions are optional.
pub(all) struct DotLayoutEdge {
  edge : @cgraph.Edge
  splines : Array[@geom.Spline]
  label_pos : @geom.Point?
  head_label_pos : @geom.Point?
  tail_label_pos : @geom.Point?
  xlabel_pos : @geom.Point?
}

///|
/// Internal recursive layout tree used by dot subpackages so tree-heavy
/// algorithms do not need to depend directly on the root public layout type.
pub(all) struct LayoutTree {
  graph : @cgraph.Graph
  bbox : @geom.Rect
  label_pos : @geom.Point?
  nodes : Array[DotLayoutNode]
  edges : Array[DotLayoutEdge]
  subgraphs : Array[LayoutTree]
}
