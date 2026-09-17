// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "layout_ports_from_final rotates record ports into LR layout coordinates" {
  @record_layout.reset_record_layout_caches()
  let graph = @dot_parser.parse_dot(
    "digraph { rankdir=LR; node [shape=record]; rotated_record [label=\"<left>   |<mid> b |   \"]; }",
  )
  let record_orientation = @layout_prep.record_layout_orientation(
    @rankdir.graph_rankdir(graph),
  )
  let node = graph.node("rotated_record")
  let size = @node_geometry.node_size(node, record_orientation)
  let ports = @record_layout.record_ports(
    node,
    @geom.Point::{ x: 0.0, y: 0.0, },
    size,
    record_orientation,
  )
  let original = match ports.get("left") {
    Some(value) => value
    None => fail("missing left port")
  }
  let rotated = layout_ports_from_final(
    ports,
    @geom.Point::{ x: 0.0, y: 0.0, },
    @rankdir.RankDir::LR,
  )
  let left_port = match rotated.get("left") {
    Some(value) => value
    None => fail("missing rotated left port")
  }

  assert_true(left_port.center.x > 0.0)
  assert_eq(left_port.size.width_pt, original.size.height_pt)
  assert_eq(left_port.size.height_pt, original.size.width_pt)
}

///|
test "dynamic_port_anchor_for_edge chooses the nearest allowed side for label ports" {
  let raw_ports : Map[String, Map[String, RecordPort]] = Map([])
  let node_ports : Map[String, RecordPort] = Map([])
  node_ports["p"] = {
    center: @geom.Point::{ x: 0.0, y: 0.0, },
    size: @node_primitives.node_size_from_points(20.0, 10.0),
    sides: PORT_SIDE_LEFT | PORT_SIDE_RIGHT,
  }
  raw_ports["n"] = node_ports

  let result = dynamic_port_anchor_for_edge(
    Some({ name: Some("p"), compass: None, }),
    "n",
    raw_ports,
    @geom.Point::{ x: 100.0, y: 100.0, },
    @geom.Point::{ x: 0.0, y: 100.0, },
    @rankdir.RankDir::TB,
    0.0,
  )

  assert_eq(result.is_dynamic, true)
  assert_eq(result.side, PORT_SIDE_LEFT)
  assert_eq(result.anchor, Some(@geom.Point::{ x: 90.0, y: 100.0, }))
}

///|
test "dynamic_port_anchor_for_edge falls back when the port resolves to a compass" {
  let result = dynamic_port_anchor_for_edge(
    Some({ name: None, compass: Some(@cgraph.Compass::E), }),
    "n",
    Map([]),
    @geom.Point::{ x: 10.0, y: 20.0, },
    @geom.Point::{ x: 100.0, y: 20.0, },
    @rankdir.RankDir::TB,
    0.0,
  )

  assert_eq(result.is_dynamic, false)
  assert_eq(result.side, 0)
  assert_eq(result.anchor, None)
}

///|
test "dynamic_port_anchor_for_edge keeps the complete self-edge record side mask" {
  let raw_ports : Map[String, Map[String, RecordPort]] = Map([])
  let node_ports : Map[String, RecordPort] = Map([])
  node_ports["left"] = {
    center: @geom.Point::{ x: -13.625, y: 0.0, },
    size: @node_primitives.node_size_from_points(27.25, 35.5),
    sides: PORT_SIDE_LEFT | PORT_SIDE_TOP | PORT_SIDE_BOTTOM,
  }
  node_ports["middle"] = {
    center: @geom.Point::{ x: 0.0, y: 0.0, },
    size: @node_primitives.node_size_from_points(22.75, 35.5),
    sides: PORT_SIDE_TOP | PORT_SIDE_BOTTOM,
  }
  raw_ports["n"] = node_ports
  let node_pos = @geom.Point::{ x: 100.0, y: 100.0, }

  let left = dynamic_port_anchor_for_edge(
    Some({ name: Some("left"), compass: None, }),
    "n",
    raw_ports,
    node_pos,
    node_pos,
    @rankdir.RankDir::TB,
    0.0,
  )
  assert_eq(left.side, PORT_SIDE_LEFT | PORT_SIDE_TOP | PORT_SIDE_BOTTOM)
  assert_eq(left.anchor, Some(@geom.Point::{ x: 86.375, y: 100.0, }))

  let middle = dynamic_port_anchor_for_edge(
    Some({ name: Some("middle"), compass: None, }),
    "n",
    raw_ports,
    node_pos,
    node_pos,
    @rankdir.RankDir::TB,
    0.0,
  )
  assert_eq(middle.side, PORT_SIDE_TOP | PORT_SIDE_BOTTOM)
  assert_eq(middle.anchor, Some(@geom.Point::{ x: 100.0, y: 100.0, }))
}
