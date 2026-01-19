///|
test "render_svg emits svg" {
  let graph = @dot.parse_dot("digraph { a -> b; }")
  let layout = @layout_dot.layout_dot(graph)
  let svg = render_svg(
    layout,
    options={
      pretty: Some(false),
      include_xml_decl: Some(false),
    },
  )
  assert_true(svg.contains("<svg"))
  assert_true(svg.contains("<path"))
  assert_true(svg.contains("<polygon"))
}
