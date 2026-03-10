///|
test "compass_uses_shape_clipping distinguishes ellipse-like and box-like polygons" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let ellipse = graph.node("ellipse")
  ellipse.set_attr("shape", "circle")
  let rect = graph.node("rect")
  rect.set_attr("shape", "box")
  let polygon = graph.node("polygon")
  polygon.set_attr("shape", "polygon")
  polygon.set_attr("sides", "4")
  polygon.set_attr("orientation", "90")

  assert_eq(compass_uses_shape_clipping(ellipse), true)
  assert_eq(compass_uses_shape_clipping(rect), false)
  assert_eq(compass_uses_shape_clipping(polygon), false)
}
