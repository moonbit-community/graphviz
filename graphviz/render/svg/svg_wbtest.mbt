// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "record labels normalize trailing whitespace before rendering" {
  let (lines, width, height) = record_label_metrics(
    "flowering plants and the incredible changes                    \\nAugust.",
    "Times-Roman", 14.0,
  )
  assert_eq(lines.length(), 2)
  assert_eq(lines[0].text, "flowering plants and the incredible changes ")
  assert_eq(width, 240.75)
  assert_eq(height, 33.0)
  let (_blank_lines, _blank_width, blank_height) = record_label_metrics(
    "first\\n\\nsecond", "Times-Roman", 14.0,
  )
  assert_eq(blank_height, 49.0)
  let (_leading_blank_lines, _leading_blank_width, leading_blank_height) = record_label_metrics(
    "\\n\\nDecl", "Times-Roman", 14.0,
  )
  assert_eq(leading_blank_height, 49.5)
}
