// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// 2D point in points (1/72 inch).
pub(all) struct Point {
  x : Double
  y : Double
} derive(Debug, Eq)

///|
pub extend Point with Debug::{to_repr}

///|
pub extend Point with Eq::{not_equal, equal}

///|
/// Size in points (1/72 inch).
pub(all) struct Size {
  width : Double
  height : Double
} derive(Debug, Eq)

///|
pub extend Size with Debug::{to_repr}

///|
pub extend Size with Eq::{not_equal, equal}

///|
/// Axis-aligned rectangle in points.
/// Invariant: llx <= urx and lly <= ury.
pub(all) struct Rect {
  llx : Double
  lly : Double
  urx : Double
  ury : Double
} derive(Debug, Eq)

///|
pub extend Rect with Debug::{to_repr}

///|
pub extend Rect with Eq::{not_equal, equal}

///|
/// Polyline path in points.
pub(all) struct Polyline {
  points : Array[Point]
} derive(Debug, Eq)

///|
pub extend Polyline with Debug::{to_repr}

///|
pub extend Polyline with Eq::{not_equal, equal}

///|
/// Cubic Bezier control points in points.
/// Invariant: points.length() >= 4 and (points.length() - 1) % 3 == 0.
pub(all) struct Bezier {
  points : Array[Point]
} derive(Debug, Eq)

///|
pub extend Bezier with Debug::{to_repr}

///|
pub extend Bezier with Eq::{not_equal, equal}

///|
/// Edge spline representation with optional clip points.
/// Invariant: points.length() >= 4 and (points.length() - 1) % 3 == 0.
pub(all) struct Spline {
  start : Point?
  end : Point?
  points : Array[Point]
} derive(Debug, Eq)

///|
pub extend Spline with Debug::{to_repr}

///|
pub extend Spline with Eq::{not_equal, equal}
