// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
/// Concentrated spline lists are in routing order, not endpoint order.
/// Only a spline carrying the corresponding marker owns that arrow.
pub fn spline_with_arrow(
  splines : Array[@geom.Spline],
  at_head : Bool,
) -> @geom.Spline? {
  for spline in splines {
    if (if at_head { spline.end } else { spline.start }) is Some(_) {
      return Some(spline)
    }
  }
  None
}
