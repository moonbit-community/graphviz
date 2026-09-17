// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn parse_double(value : String, fallback : Double) -> Double {
  try @string.parse_double(value) catch {
    _ => fallback
  } noraise {
    parsed => parsed
  }
}
