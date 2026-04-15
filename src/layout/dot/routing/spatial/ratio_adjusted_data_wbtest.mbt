// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "build_routing_ratio_adjusted_data keeps geometry unchanged when ratio fill is inactive" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("a")
  let size = sample_node_size(10.0, 10.0)
  let output_sizes : Map[String, NodeSize] = { "a": size }
  let positions : Map[String, @geom.Point] = { "a": { x: 5.0, y: 5.0 } }
  let position_state = sample_position_result(
    positions,
    Map::new(),
    { "cluster": 1.5 },
    { "cluster": 2.5 },
    { 0: 5.0 },
    { 0: 5.0 },
    { 0: 5.0 },
  )
  let nodes_out = build_routing_layout_nodes(
    [node],
    positions,
    output_sizes,
    RecordOrientation::Horizontal,
  )
  let cluster_bboxes : Map[String, @geom.Rect] = {
    "cluster": { llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 },
  }
  let label_ports_map : Map[String, Map[String, RecordPort]] = {
    "a": { "p": sample_record_port({ x: 1.0, y: 2.0 }, 2.0, 4.0) },
  }
  let prep = sample_layout_prep(
    RankDir::TB,
    [node],
    [],
    false,
    output_sizes,
    output_sizes,
  )

  let adjusted = build_routing_ratio_adjusted_data({
    graph,
    prep,
    rank_data: sample_rank_data(graph, [node]),
    nodes_out,
    positions_state: position_state,
    cluster_bboxes,
    label_ports_map,
    label_ports_raw: label_ports_map,
  })

  assert_false(adjusted.ratio_scaled)
  assert_close(adjusted.ratio_sx, 1.0)
  assert_close(adjusted.ratio_sy, 1.0)
  assert_eq(
    adjusted.positions_state.positions.get("a"),
    Some({ x: 5.0, y: 5.0 }),
  )
  assert_eq(
    adjusted.cluster_bboxes.get("cluster"),
    Some({ llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 }),
  )
  let adjusted_ports = require_map_value(
    adjusted.label_ports_map,
    "a",
    "adjusted ports",
  )
  let adjusted_port = require_map_value(adjusted_ports, "p", "adjusted port")
  assert_point_close(adjusted_port.center, { x: 1.0, y: 2.0 })
  assert_close(adjusted_port.size.width_pt, 2.0)
  assert_close(adjusted_port.size.height_pt, 4.0)
}

///|
test "build_routing_ratio_adjusted_data scales positions cluster boxes and port maps for ratio fill" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  graph.set_attr("ratio", "fill")
  graph.set_attr("size", "1,2")
  let node = graph.node("a")
  let size = sample_node_size(10.0, 10.0)
  let output_sizes : Map[String, NodeSize] = { "a": size }
  let positions : Map[String, @geom.Point] = { "a": { x: 5.0, y: 5.0 } }
  let vnode_positions : Map[String, @geom.Point] = { "v1": { x: 1.5, y: 2.5 } }
  let position_state = sample_position_result(
    positions,
    vnode_positions,
    { "cluster": 1.5 },
    { "cluster": 2.5 },
    { 0: 5.0 },
    { 0: 5.0 },
    { 0: 5.0 },
  )
  let nodes_out = build_routing_layout_nodes(
    [node],
    positions,
    output_sizes,
    RecordOrientation::Horizontal,
  )
  let cluster_bboxes : Map[String, @geom.Rect] = {
    "cluster": { llx: 1.0, lly: 2.0, urx: 3.0, ury: 4.0 },
  }
  let label_ports_map : Map[String, Map[String, RecordPort]] = {
    "a": { "p": sample_record_port({ x: 1.0, y: 2.0 }, 2.0, 4.0) },
  }
  let prep = sample_layout_prep(
    RankDir::TB,
    [node],
    [],
    false,
    output_sizes,
    output_sizes,
  )

  let adjusted = build_routing_ratio_adjusted_data({
    graph,
    prep,
    rank_data: sample_rank_data(graph, [node]),
    nodes_out,
    positions_state: position_state,
    cluster_bboxes,
    label_ports_map,
    label_ports_raw: label_ports_map,
  })

  assert_true(adjusted.ratio_scaled)
  assert_close(adjusted.ratio_sx, 7.2)
  assert_close(adjusted.ratio_sy, 14.4)
  assert_eq(
    adjusted.positions_state.positions.get("a"),
    Some({ x: 36.0, y: 72.0 }),
  )
  assert_eq(
    adjusted.positions_state.vnode_positions.get("v1"),
    Some({ x: 11.0, y: 36.0 }),
  )
  assert_close(
    require_map_value(
      adjusted.positions_state.cluster_ln_x,
      "cluster",
      "cluster ln x",
    ),
    10.8,
  )
  assert_close(
    require_map_value(
      adjusted.positions_state.cluster_rn_x,
      "cluster",
      "cluster rn x",
    ),
    18.0,
  )
  assert_eq(adjusted.positions_state.rank_y.get(0), Some(72.0))
  let cluster_bbox = require_map_value(
    adjusted.cluster_bboxes,
    "cluster",
    "scaled cluster bbox",
  )
  assert_close(cluster_bbox.llx, 7.2)
  assert_close(cluster_bbox.lly, 28.8)
  assert_close(cluster_bbox.urx, 21.6)
  assert_close(cluster_bbox.ury, 57.6)
  let adjusted_ports = require_map_value(
    adjusted.label_ports_map,
    "a",
    "scaled ports",
  )
  let adjusted_port = require_map_value(adjusted_ports, "p", "scaled port")
  assert_point_close(adjusted_port.center, { x: 7.2, y: 28.8 })
  assert_close(adjusted_port.size.width_pt, 14.4)
  assert_close(adjusted_port.size.height_pt, 57.6)
}
