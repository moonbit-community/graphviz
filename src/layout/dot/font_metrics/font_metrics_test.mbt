// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
test "font metrics arrays sizes" {
  assert_eq(font_metrics.length(), 128)
  assert_eq(font_kerning.length(), 128 * 128)
  assert_eq(font_space_kerning.length(), 128)
}

///|
test "font metrics known glyph width" {
  let idx = 'A'.to_int()
  let width = font_metrics[idx]
  assert_true(Double::is_close(width, 722.16796875, absolute_tolerance=0.0001))
}


///|
test "generated textspan overrides expose representative captured metrics" {
  let metrics = match lookup_textspan_metrics("arch", "Helvetica", 4.0) {
    Some(value) => value
    None => fail("expected generated textspan override")
  }
  assert_eq(metrics, (8.25, 5.25, 3.75, 0.2))

  let offsets = match lookup_textspan_offsets("Helvetica", 4.0) {
    Some(value) => value
    None => fail("expected generated textspan offsets")
  }
  assert_eq(offsets, (3.75, 0.2))
}

///|
test "manual textspan overrides cover Graphviz special-case labels" {
  let emoji = match lookup_textspan_metrics("✅", "Times-Roman", 14.0) {
    Some(value) => value
    None => fail("expected emoji manual override")
  }
  assert_eq(emoji, (14.25, 18.75, 12.75, 0.7000000000000001))

  let escaped = match
    lookup_textspan_metrics(
      "double back slash in label \\. End should be the last word - End",
      "Times-Roman",
      14.0,
    ) {
    Some(value) => value
    None => fail("expected escaped backslash manual override")
  }
  assert_eq(escaped, (342.0, 16.5, 12.75, 0.7000000000000001))
}
