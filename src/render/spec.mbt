///|
/// Text alignment for draw operations.
pub(all) enum TextAlign {
  Left
  Center
  Right
} derive(Show, Eq)

///|
/// Font description (size in points).
pub(all) struct Font {
  name : String
  size : Double
} derive(Show, Eq)

///|
/// Gradient stop for linear/radial gradients.
pub(all) struct GradientStop {
  offset : Double
  color : String
} derive(Show, Eq)

///|
/// Linear gradient definition.
pub(all) struct LinearGradient {
  start : @geom.Point
  end : @geom.Point
  stops : Array[GradientStop]
} derive(Show, Eq)

///|
/// Radial gradient definition.
pub(all) struct RadialGradient {
  start_center : @geom.Point
  start_radius : Double
  end_center : @geom.Point
  end_radius : Double
  stops : Array[GradientStop]
} derive(Show, Eq)

///|
/// Gradient color specification.
pub(all) enum Gradient {
  Linear(LinearGradient)
  Radial(RadialGradient)
} derive(Show, Eq)

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
} derive(Show, Eq)

///|
/// Generate arrowhead drawing primitives for a single arrow tip.
#declaration_only
pub fn arrow_primitives(
  tip : @geom.Point,
  from : @geom.Point,
  size : Double,
  arrowhead : String?,
) -> Array[DrawOp] {
  ...
}
