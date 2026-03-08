///|
test "point_for_name_or_origin returns stored positions and defaults missing names to origin" {
  let positions : Map[String, @geom.Point] = Map::new()
  positions["a"] = { x: 12.5, y: -3.0 }

  assert_eq(point_for_name_or_origin(positions, "a"), { x: 12.5, y: -3.0 })
  assert_eq(point_for_name_or_origin(positions, "missing"), { x: 0.0, y: 0.0 })
}

///|
test "size_for_name_or_node uses cached sizes before falling back to node sizing" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let cached_size = @node_primitives.node_size_from_points(10.0, 8.0)
  let fallback_size = @node_primitives.node_size_from_points(30.0, 12.0)
  let sizes : Map[String, NodeSize] = Map::new()
  sizes["a"] = cached_size
  let fallback_calls = Ref::new(0)

  let cached = size_for_name_or_node(sizes, "a", a, _node => {
    fallback_calls.val = fallback_calls.val + 1
    fallback_size
  })
  let fallback = size_for_name_or_node(sizes, "b", b, _node => {
    fallback_calls.val = fallback_calls.val + 1
    fallback_size
  })

  assert_eq(cached.width_pt, 10.0)
  assert_eq(cached.height_pt, 8.0)
  assert_eq(fallback.width_pt, 30.0)
  assert_eq(fallback.height_pt, 12.0)
  assert_eq(fallback_calls.val, 1)
}

///|
test "cluster_bbox_if_named ignores empty keys and looks up named clusters" {
  let bboxes : Map[String, @geom.Rect] = Map::new()
  let rect : @geom.Rect = { llx: 1.0, lly: 2.0, urx: 4.0, ury: 6.0 }
  bboxes["cluster0"] = rect

  assert_eq(cluster_bbox_if_named(bboxes, ""), None)
  assert_eq(cluster_bbox_if_named(bboxes, "cluster0"), Some(rect))
  assert_eq(cluster_bbox_if_named(bboxes, "missing"), None)
}

///|
test "arrowhead inclusion respects edge dir and swap orientation" {
  assert_eq(edge_include_arrowheads(@edge_semantics.EdgeDir::Forward), (false, true))
  assert_eq(edge_include_arrowheads(@edge_semantics.EdgeDir::Back), (true, false))
  assert_eq(edge_include_arrowheads(@edge_semantics.EdgeDir::Both), (true, true))
  assert_eq(edge_include_arrowheads(@edge_semantics.EdgeDir::None), (false, false))

  assert_eq(route_include_arrowheads(true, false, false), (true, false))
  assert_eq(route_include_arrowheads(true, false, true), (false, true))
}

///|
test "edge_style_is_dotted is gated by complex tuning and matches style case-insensitively" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let dotted = graph.edge(graph.node("a"), graph.node("b"))
  dotted.set_attr("style", "bold,DOTTED")
  let solid = graph.edge(graph.node("c"), graph.node("d"))
  solid.set_attr("style", "solid")

  assert_false(edge_style_is_dotted(dotted, false))
  assert_true(edge_style_is_dotted(dotted, true))
  assert_false(edge_style_is_dotted(solid, true))
}
