///|
test "label compass uses inherited exposure even when inset from node outline" {
  let ports : Map[String, Map[String, RecordPort]] = {
    "n": {
      "field": {
        center: { x: 0.0, y: 0.0, },
        size: @node_primitives.node_size_from_points(20.0, 10.0),
        sides: PORT_SIDE_TOP | PORT_SIDE_LEFT,
      },
    },
  }
  @test.assert_eq(
    label_port_compass_side(
      "n",
      Some({ name: Some("field"), compass: Some(@cgraph.Compass::NE), }),
      ports,
    ),
    Some(PORT_SIDE_TOP),
  )
  @test.assert_eq(
    label_port_compass_side(
      "n",
      Some({ name: Some("field"), compass: Some(@cgraph.Compass::SE), }),
      ports,
    ),
    Some(0),
  )
}
