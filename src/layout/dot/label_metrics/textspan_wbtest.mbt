// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "generated override metrics flow through label text measurement" {
  assert_eq(
    label_text_metrics("arch", "Helvetica", 4.0),
    (8.25, 5.25, 3.75, 0.2),
  )
}

///|
test "multiline overrides use widest line total height and font offsets" {
  assert_eq(
    label_text_metrics(
      "Edge Label A\\nEdge Label B Longer", "Times-Roman", 14.0,
    ),
    (117.75, 33.0, 12.75, 0.7000000000000001),
  )
}

///|
test "regular labels keep a trailing break as an empty line" {
  assert_eq(
    label_text_metrics("a\\n", "Times-Roman", 14.0),
    (6.0, 32.5, 12.75, 0.7000000000000001),
  )
}

///|
test "record labels trim a trailing break line" {
  assert_eq(
    record_label_text_dimensions("a\\n", "Times-Roman", 14.0),
    (6.0, 16.5),
  )
}

///|
test "monospace measurement depends on column counts not glyph shapes" {
  let wide = label_text_dimensions("WW\\nii", "monospace", 10.0)
  let same_columns = label_text_dimensions("ab\\ncd", "monospace", 10.0)
  let wider_columns = label_text_dimensions("abc\\nde", "monospace", 10.0)
  assert_eq(wide, same_columns)
  assert_true(wider_columns.0 > wide.0)
  assert_eq(wider_columns.1, wide.1)
}

///|
test "fallback offsets apply when font has no captured offsets" {
  let (width, height, yoffset_layout, yoffset_centerline) = label_text_metrics(
    "A", "UnknownFont", 10.0,
  )
  assert_true(width > 0.0)
  assert_eq(height, 12.0)
  assert_eq(yoffset_layout, 0.0)
  assert_eq(yoffset_centerline, 1.0)
}
