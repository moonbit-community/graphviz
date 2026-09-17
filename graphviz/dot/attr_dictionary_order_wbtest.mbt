// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "attribute dictionaries use UTF-8 lexical order for built-in and custom names" {
  let expected = [
    "URL", "_draw_", "aa", "b", "compound", "edgetooltip", "edgeurl", "headURL",
    "head_lp", "headlabel", "label", "labelURL", "pos", "rotate", "tailURL", "tail_lp",
    "tooltip", "z", "é", "😀",
  ]
  let attrs : Array[(String, String)] = []
  for index = expected.length() - 1; index >= 0; index = index - 1 {
    attrs.push((expected[index], "value"))
  }
  let sorted = sort_attrs(attrs)
  @test.assert_eq(sorted.map(pair => pair.0), expected)
  @test.assert_eq(sort_attrs(sorted), sorted)
  @test.assert_eq(attrs[0].0, "😀")
}
