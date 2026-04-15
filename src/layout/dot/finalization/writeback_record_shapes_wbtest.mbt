// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "apply_layout_tree_writeback writes rects only for non-html non-mrecord record shapes" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let record = graph.node("record")
  record.set_attr("shape", "record")
  record.set_attr("label", "<left>l|<right>r")
  let mrecord = graph.node("mrecord")
  mrecord.set_attr("shape", "mrecord")
  mrecord.set_attr("label", "<left>l|<right>r")
  let html_record = graph.node("html_record")
  html_record.set_attr("shape", "record")
  html_record.set_attr("label", "<<TABLE><TR><TD>x</TD></TR></TABLE>>")

  let record_layout = writeback_make_node_layout(
    record,
    { x: 10.0, y: 20.0 },
    2.0,
    1.0,
  )
  let mrecord_layout = writeback_make_node_layout(
    mrecord,
    { x: 40.0, y: 20.0 },
    2.0,
    1.0,
  )
  let html_record_layout = writeback_make_node_layout(
    html_record,
    { x: 70.0, y: 20.0 },
    2.0,
    1.0,
  )
  let layout = writeback_make_layout_tree(
    graph,
    { llx: 0.0, lly: 0.0, urx: 100.0, ury: 40.0 },
    nodes=[record_layout, mrecord_layout, html_record_layout],
  )

  apply_layout_tree_writeback(layout)

  let size = @node_primitives.node_size_from_points(2.0 * 72.0, 1.0 * 72.0)
  let expected_rects = format_rects(
    @record_layout.record_rects(
      record,
      record_layout.pos,
      size,
      @layout_prep.record_layout_orientation(@rankdir.graph_rankdir(graph)),
    ),
  )

  assert_eq(record.get_attr("rects"), Some(expected_rects))
  assert_eq(mrecord.get_attr("rects"), None)
  assert_eq(html_record.get_attr("rects"), None)
}
