///|
test "top and bottom labels use space before additional outlines" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=box height=2 label=\"x\"]; a [labelloc=t]; b [labelloc=b]; c [labelloc=b peripheries=3]; d; }",
  )
  let (_, height) = @label_metrics.label_text_dimensions(
    "x", "Times-Roman", 14.0,
  )
  assert_close(
    node_label_y_offset(graph.node("a")),
    (144.0 - height) / 2.0,
    0.000001,
  )
  assert_close(
    node_label_y_offset(graph.node("b")),
    (height - 144.0) / 2.0,
    0.000001,
  )
  assert_close(
    node_label_y_offset(graph.node("c")),
    node_label_y_offset(graph.node("b")),
    0.000001,
  )
  assert_close(node_label_y_offset(graph.node("d")), 0.0, 0.000001)
}

///|
test "node label space excludes padding and additional peripheries" {
  let graph = @dot_parser.parse_dot(
    "digraph { node [shape=box width=3 label=\"aaaaaaaaaaaaaa\\nddd\\l\"]; a; b [nojustify=true]; c [peripheries=3]; }",
  )
  assert_close(node_label_space(graph.node("a")).unwrap(), 200.0, 0.000001)
  assert_close(node_label_space(graph.node("b")).unwrap(), 84.0, 0.000001)
  assert_close(node_label_space(graph.node("c")).unwrap(), 200.0, 0.000001)
}

///|
test "ellipse label space uses the chord at the padded label height" {
  let graph = @dot_parser.parse_dot(
    "digraph { a [shape=ellipse width=3 height=2 margin=0 label=\"aaaaaaaaaaaaaa\\nddd\\l\"]; }",
  )
  let ratio = 33.0 / 144.0
  let expected = 216.0 * Double::sqrt(1.0 - ratio * ratio)
  assert_close(node_label_space(graph.node("a")).unwrap(), expected, 0.000001)
}
