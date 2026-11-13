// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Font size and all returned distances use points (1/72 inch), not device pixels.
#derive(Debug, Eq)
pub(all) struct Font {
  name : String
  size_pt : Double
}

///|
pub extend Font with Debug::{to_repr}

///|
pub extend Font with Eq::{not_equal, equal}

///|
/// Horizontal ink bounds are relative to the run origin; ascent and descent
/// are distances above and below an alphabetic baseline. Unlike advance width,
/// these bounds do not include whitespace.
#derive(Debug, Eq)
pub(all) struct InkBounds {
  left_pt : Double
  right_pt : Double
  ascent_pt : Double
  descent_pt : Double
}

///|
pub extend InkBounds with Debug::{to_repr}

///|
pub extend InkBounds with Eq::{not_equal, equal}

///|
/// Advance width and logical font height of a complete, decoded text run.
/// The logical height may include font leading. Ascent/descent are font bounds,
/// not the run's ink bounds. Layout owns line spacing, padding and baselines.
#derive(Debug, Eq)
pub(all) struct Metrics {
  width_pt : Double
  height_pt : Double
  ascent_pt : Double
  descent_pt : Double
  ink : InkBounds?
}

///|
pub extend Metrics with Debug::{to_repr}

///|
pub extend Metrics with Eq::{not_equal, equal}

///|
/// Implementations measure the whole run, including shaping and kerning.
/// There is deliberately no default implementation or provider fallback.
pub(open) trait Measurer {
  fn measure(Self, Font, String) -> Metrics
}
