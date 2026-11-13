// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Optional captured metric calibration, supplied explicitly by the application.
/// The tuple is (width, logical height, layout offset, optical center offset),
/// in points. Optical centering is distinct from a font's ascent.
/// This contains no label parser or line-layout algorithm.
pub(all) struct Calibration {
  span : (@measurement.Font, String) -> (Double, Double, Double, Double)?
  offsets : (@measurement.Font) -> (Double, Double)?
  centered_x : (String) -> Double
}

///|
/// Bound to one layout and retained by its output for subsequent rendering.
/// The measurer may outlive a layout and retain its own measurement cache.
pub struct Context {
  measurer : &@measurement.Measurer
  calibration : Calibration?
}

///|
pub fn Context::new(
  measurer : &@measurement.Measurer,
  calibration~ : Calibration? = None,
) -> Context {
  { measurer, calibration, }
}

///|
pub fn Context::measure(
  self : Context,
  font : @measurement.Font,
  text : String,
) -> @measurement.Metrics {
  self.measurer.measure(font, text)
}

///|
pub fn Context::calibrated_span(
  self : Context,
  font : @measurement.Font,
  text : String,
) -> (Double, Double, Double, Double)? {
  self.calibration.bind(calibration => (calibration.span)(font, text))
}

///|
/// Preserve Graphviz's baseline convention; ascent is not a replacement for
/// either of these offsets. Providers without captured offsets use the existing
/// layout convention, not a second font-measurement implementation.
pub fn Context::text_offsets(
  self : Context,
  font : @measurement.Font,
) -> (Double, Double) {
  self.calibration
  .bind(calibration => (calibration.offsets)(font))
  .unwrap_or((0.0, font.size_pt * 0.1))
}

///|
pub fn Context::centered_text_x(
  self : Context,
  value : Double,
  font_name : String,
) -> Double {
  value +
  self.calibration.map_or(0.0, calibration => {
    (calibration.centered_x)(font_name)
  })
}
