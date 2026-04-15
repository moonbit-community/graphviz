// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
/// Text alignment for draw operations.
pub(all) enum TextAlign {
  Left
  Center
  Right
} derive(Debug, Eq)

///|
/// Font description (size in points).
pub(all) struct Font {
  name : String
  size : Double
} derive(Debug, Eq)

///|
/// Gradient stop for linear/radial gradients.
pub(all) struct GradientStop {
  offset : Double
  color : String
} derive(Debug, Eq)

///|
/// Linear gradient definition.
pub(all) struct LinearGradient {
  start : @geom.Point
  end : @geom.Point
  stops : Array[GradientStop]
} derive(Debug, Eq)

///|
/// Radial gradient definition.
pub(all) struct RadialGradient {
  start_center : @geom.Point
  start_radius : Double
  end_center : @geom.Point
  end_radius : Double
  stops : Array[GradientStop]
} derive(Debug, Eq)

///|
/// Gradient color specification.
pub(all) enum Gradient {
  Linear(LinearGradient)
  Radial(RadialGradient)
} derive(Debug, Eq)

///|
/// Drawing primitive operations (points in points).
pub(all) enum DrawOp {
  Ellipse(filled~ : Bool, rect~ : @geom.Rect)
  Polygon(filled~ : Bool, points~ : Array[@geom.Point])
  Bezier(filled~ : Bool, points~ : Array[@geom.Point])
  Polyline(points~ : Array[@geom.Point])
  Text(pos~ : @geom.Point, align~ : TextAlign, width~ : Double, text~ : String)
  Image(rect~ : @geom.Rect, name~ : String)
  FillColor(color~ : String)
  PenColor(color~ : String)
  GradFill(gradient~ : Gradient)
  GradPen(gradient~ : Gradient)
  Font(font~ : Font)
  Style(name~ : String)
  FontChar(codepoint~ : UInt)
} derive(Debug, Eq)

///|
/// Generate arrowhead drawing primitives for a single arrow tip.
#declaration_only
pub fn arrow_primitives(
  tip : @geom.Point,
  from : @geom.Point,
  size : Double,
  penwidth : Double,
  arrowhead : String?,
) -> Array[DrawOp] {
  ...
}
