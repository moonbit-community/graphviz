// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_routing_port_layout_maps gates on port edges and rotates record ports into layout coordinates" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("record")
  node.set_attr("shape", "record")
  node.set_attr("label", "<left>l|<right>r")
  let rankdir = RankDir::LR
  let orientation = @layout_prep.record_layout_orientation(rankdir)
  let size = @node_geometry.node_size(node, orientation)
  let nodes_out : Array[DotLayoutNode] = [
    {
      node,
      pos: { x: 100.0, y: 50.0 },
      width_in: size.width_in,
      height_in: size.height_in,
      label_pos: None,
      xlabel_pos: None,
    },
  ]
  let output_sizes : Map[String, NodeSize] = { "record": size }

  let disabled = build_routing_port_layout_maps(
    nodes_out, output_sizes, orientation, rankdir, false,
  )
  assert_eq(disabled.label_ports_map.length(), 0)
  assert_eq(disabled.label_ports_raw.length(), 0)

  let enabled = build_routing_port_layout_maps(
    nodes_out, output_sizes, orientation, rankdir, true,
  )
  let raw_ports = require_map_value(
    enabled.label_ports_raw,
    "record",
    "raw ports",
  )
  let layout_ports = require_map_value(
    enabled.label_ports_map,
    "record",
    "layout ports",
  )
  let raw_left = require_map_value(raw_ports, "left", "raw left")
  let layout_left = require_map_value(layout_ports, "left", "layout left")
  let expected_offset = @port_geometry.layout_port_offset(
    raw_left.center,
    rankdir,
  )

  assert_eq(raw_ports.length(), 2)
  assert_eq(layout_ports.length(), 2)
  assert_point_close(layout_left.center, {
    x: 100.0 + expected_offset.x,
    y: 50.0 + expected_offset.y,
  })
  assert_close(layout_left.size.width_pt, raw_left.size.height_pt)
  assert_close(layout_left.size.height_pt, raw_left.size.width_pt)
}
