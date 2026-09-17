// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
async test "biglabel interior record port does not enlarge the root bbox" {
  let graph = @dot_fs.parse_dot_file(
    "../refs/graphviz/tests/graphs/biglabel.gv",
  )
  let layout = @layout_dot.layout_dot(graph)
  assert_eq(layout.bbox.ury, 1429.5)
}
