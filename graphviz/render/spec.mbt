// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Text alignment for draw operations.
#derive(Debug, Eq)
pub(all) enum TextAlign {
  Left
  Center
  Right
}

///|
pub extend TextAlign with Debug::{to_repr}

///|
pub extend TextAlign with Eq::{not_equal, equal}

///|
/// Font description (size in points).
#derive(Debug, Eq)
pub(all) struct Font {
  name : String
  size : Double
}

///|
pub extend Font with Debug::{to_repr}

///|
pub extend Font with Eq::{not_equal, equal}

///|
/// Gradient stop for linear/radial gradients.
#derive(Debug, Eq)
pub(all) struct GradientStop {
  offset : Double
  color : String
}

///|
pub extend GradientStop with Debug::{to_repr}

///|
pub extend GradientStop with Eq::{not_equal, equal}

///|
/// Linear gradient definition.
#derive(Debug, Eq)
pub(all) struct LinearGradient {
  start : @geom.Point
  end : @geom.Point
  stops : Array[GradientStop]
}

///|
pub extend LinearGradient with Debug::{to_repr}

///|
pub extend LinearGradient with Eq::{not_equal, equal}

///|
/// Radial gradient definition.
#derive(Debug, Eq)
pub(all) struct RadialGradient {
  start_center : @geom.Point
  start_radius : Double
  end_center : @geom.Point
  end_radius : Double
  stops : Array[GradientStop]
}

///|
pub extend RadialGradient with Debug::{to_repr}

///|
pub extend RadialGradient with Eq::{not_equal, equal}

///|
/// Gradient color specification.
#derive(Debug, Eq)
pub(all) enum Gradient {
  Linear(LinearGradient)
  Radial(RadialGradient)
}

///|
pub extend Gradient with Debug::{to_repr}

///|
pub extend Gradient with Eq::{not_equal, equal}

///|
/// Drawing primitive operations (points in points).
#derive(Debug, Eq)
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
  FontChar(codepoint~ : UInt32)
}

///|
pub extend DrawOp with Debug::{to_repr}

///|
pub extend DrawOp with Eq::{not_equal, equal}

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
