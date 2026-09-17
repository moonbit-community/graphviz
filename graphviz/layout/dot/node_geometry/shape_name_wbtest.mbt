///|
test "unknown shapes use box dimensions without changing the source attribute" {
  let graph = @dot_parser.parse_dot(
    "digraph { a [shape=sdl_task label=\"sdl_task\"]; b [shape=box label=\"sdl_task\"]; }",
  )
  let a = graph.node("a")
  let first = node_size(a, @layout_prep.RecordOrientation::Horizontal)
  let second = node_size(
    graph.node("b"),
    @layout_prep.RecordOrientation::Horizontal,
  )
  assert_close(first.width_in, second.width_in, 0.000001)
  assert_close(first.height_in, second.height_in, 0.000001)
  assert_true(a.get_attr("shape") == Some("sdl_task"))
}
