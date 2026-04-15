// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "scale_edge_layout_output and scale_record_port_maps keep nested geometry synchronized" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let edges : Array[DotLayoutEdge] = [
    {
      edge,
      splines: [
        {
          start: Some({ x: 1.0, y: 2.0 }),
          end: Some({ x: 7.0, y: 8.0 }),
          points: [
            { x: 1.0, y: 2.0 },
            { x: 3.0, y: 4.0 },
            { x: 5.0, y: 6.0 },
            { x: 7.0, y: 8.0 },
          ],
        },
      ],
      label_pos: Some({ x: 2.0, y: 3.0 }),
      head_label_pos: Some({ x: 4.0, y: 5.0 }),
      tail_label_pos: Some({ x: 0.0, y: 1.0 }),
      xlabel_pos: Some({ x: 6.0, y: 7.0 }),
    },
  ]
  let scaled_edges = scale_edge_layout_output(edges, 2.0, 3.0)
  let scaled_spline = scaled_edges[0].splines[0]
  assert_eq(scaled_spline.start, Some({ x: 2.0, y: 6.0 }))
  assert_eq(scaled_spline.end, Some({ x: 14.0, y: 24.0 }))
  assert_eq(scaled_spline.points, [
    { x: 2.0, y: 6.0 },
    { x: 6.0, y: 12.0 },
    { x: 10.0, y: 18.0 },
    { x: 14.0, y: 24.0 },
  ])
  assert_eq(scaled_edges[0].label_pos, Some({ x: 4.0, y: 9.0 }))
  assert_eq(scaled_edges[0].head_label_pos, Some({ x: 8.0, y: 15.0 }))
  assert_eq(scaled_edges[0].tail_label_pos, Some({ x: 0.0, y: 3.0 }))
  assert_eq(scaled_edges[0].xlabel_pos, Some({ x: 12.0, y: 21.0 }))

  let ports : Map[String, Map[String, @record_geometry.RecordPort]] = Map::new()
  ports["node"] = {
    "p": {
      center: { x: 4.0, y: 5.0 },
      size: @node_primitives.node_size_from_points(10.0, 20.0),
      sides: 3,
    },
  }
  let scaled_ports = scale_record_port_maps(ports, 2.0, 0.5)
  let node_ports = match scaled_ports.get("node") {
    Some(value) => value
    None => fail("missing node ports")
  }
  let port = match node_ports.get("p") {
    Some(value) => value
    None => fail("missing port")
  }
  assert_eq(port.center, { x: 8.0, y: 2.5 })
  assert_eq(port.size.width_pt, 20.0)
  assert_eq(port.size.height_pt, 10.0)
  assert_eq(port.sides, 3)
}

///|
test "scale_edge_layout_output preserves absent optional geometry while scaling spline points" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let scaled_edges = scale_edge_layout_output(
    [
      {
        edge,
        splines: [{ start: None, end: None, points: [{ x: 1.0, y: 2.0 }] }],
        label_pos: None,
        head_label_pos: None,
        tail_label_pos: None,
        xlabel_pos: None,
      },
    ],
    2.0,
    3.0,
  )

  let scaled_spline = scaled_edges[0].splines[0]
  assert_eq(scaled_spline.start, None)
  assert_eq(scaled_spline.end, None)
  assert_eq(scaled_spline.points, [{ x: 2.0, y: 6.0 }])
  assert_eq(scaled_edges[0].label_pos, None)
  assert_eq(scaled_edges[0].head_label_pos, None)
  assert_eq(scaled_edges[0].tail_label_pos, None)
  assert_eq(scaled_edges[0].xlabel_pos, None)
}
