///|
test "parse_arrow_flags handles defaults synonyms and invalid values" {
  assert_eq(parse_arrow_flags(None), [ARR_TYPE_NORM])
  assert_eq(parse_arrow_flags(Some("")), [ARR_TYPE_NORM])
  assert_eq(
    parse_arrow_flags(Some("invempty")),
    [ARR_TYPE_NORM | ARR_MOD_INV | ARR_MOD_OPEN],
  )
  assert_eq(parse_arrow_flags(Some("crowtee")), [ARR_TYPE_CROW, ARR_TYPE_TEE])
  assert_eq(parse_arrow_flags(Some("l")), [ARR_TYPE_NORM | ARR_MOD_LEFT])
  assert_eq(parse_arrow_flags(Some("bogus")), [])
}

///|
test "arrow_length_for_edge swaps oriented attrs and clamps override" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(tail, head)
  edge.set_attr("arrowtail", "crow")
  edge.set_attr("arrowhead", "box")
  edge.set_attr("arrowsize", "1.5")
  edge.set_attr("penwidth", "2.0")

  let base = arrow_length_for_edge(edge, true, true, None)
  let swapped = arrow_length_for_edge_oriented(edge, true, true, None, true)
  let override_len = arrow_length_for_edge(edge, true, true, Some(0.5))
  let head_only = arrow_length_for_edge(edge, false, true, None)

  assert_true(base.tail > 0.5)
  assert_true(base.head > 0.5)
  assert_eq(swapped.tail, base.head)
  assert_eq(swapped.head, base.tail)
  assert_eq(override_len.tail, 0.5)
  assert_eq(override_len.head, 0.5)
  assert_eq(head_only.tail, 0.0)
  assert_eq(head_only.head, base.head)
}
