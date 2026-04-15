// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
pub fn parse_double(value : String?, fallback : Double) -> Double {
  match value {
    Some(text) =>
      try @string.parse_double(text) catch {
        _ => fallback
      } noraise {
        parsed => parsed
      }
    None => fallback
  }
}
