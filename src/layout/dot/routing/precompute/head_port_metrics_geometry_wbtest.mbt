// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
fn sample_route_port_geometry(
  center : @geom.Point,
  size? : @node_primitives.NodeSize = @node_primitives.node_size_from_points(
    10.0, 10.0,
  ),
) -> RoutePortGeometry {
  { center, size }
}

///|
test "head_metric_key_for_edge prefers explicit head ports then record-shape fallback" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let record_head = graph.node("record_head")
  record_head.set_attr("shape", "record")
  let plain_head = graph.node("plain_head")

  let explicit = graph.edge(tail, record_head, head_port={
    name: Some("p"),
    compass: Some(@cgraph.Compass::E),
  })
  let record_fallback = graph.edge(tail, record_head, name="record_fallback")
  let plain = graph.edge(tail, plain_head)

  assert_eq(
    head_metric_key_for_edge(explicit, @record_geometry.is_record_shape),
    "record_head:p:e",
  )
  assert_eq(
    head_metric_key_for_edge(record_fallback, @record_geometry.is_record_shape),
    "record_head",
  )
  assert_eq(
    head_metric_key_for_edge(plain, @record_geometry.is_record_shape),
    "",
  )
}

///|
test "head_metric_distance_for_edge uses sampled port centers in current routing coordinates" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let head = graph.node("head")
  let edge = graph.edge(
    tail,
    head,
    tail_port={ name: Some("t"), compass: None },
    head_port={ name: Some("h"), compass: None },
  )

  let positions : Map[String, @geom.Point] = Map::new()
  positions["tail"] = { x: 0.0, y: 0.0 }
  positions["head"] = { x: 2.0, y: 0.0 }

  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["tail"] = @node_primitives.node_size_from_points(10.0, 10.0)

  let distance = head_metric_distance_for_edge(
    edge,
    positions,
    sizes,
    _node => @node_primitives.node_size_from_points(20.0, 20.0),
    (name, _port, pos, size) => {
      if name == "tail" {
        sample_route_port_geometry({
          x: pos.x + size.width_pt / 10.0,
          y: pos.y + 2.0,
        })
      } else {
        sample_route_port_geometry({
          x: pos.x + size.width_pt / 10.0,
          y: pos.y + 6.0,
        })
      }
    },
  )

  assert_eq(distance, 5.0)
}

///|
test "build_head_port_metrics_from_geometry aggregates only keyed edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail = graph.node("tail")
  let record_head = graph.node("record_head")
  record_head.set_attr("shape", "record")
  let plain_head = graph.node("plain_head")

  let first = graph.edge(tail, record_head, name="first")
  let second = graph.edge(tail, record_head, name="second")
  let ignored = graph.edge(tail, plain_head, name="ignored")

  let positions : Map[String, @geom.Point] = Map::new()
  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  let metrics = build_head_port_metrics_from_geometry(
    [first, second, ignored],
    true,
    positions,
    sizes,
    @record_geometry.is_record_shape,
    _node => @node_primitives.node_size_from_points(10.0, 10.0),
    (_name, _port, _pos, _size) => {
      sample_route_port_geometry({ x: 0.0, y: 0.0 })
    },
  )

  assert_eq(metrics.head_port_counts.get("record_head"), Some(2))
  assert_eq(metrics.head_port_min_dist.get("record_head"), Some(0.0))
  assert_eq(metrics.head_port_max_dist.get("record_head"), Some(0.0))
  assert_eq(metrics.head_port_counts.get("plain_head"), None)
}

///|
test "build_dot_head_port_metrics uses explicit label-port geometry and record fallback centers" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let tail_port = graph.node("tail_port")
  let tail_plain = graph.node("tail_plain")
  let record_head = graph.node("record_head")
  record_head.set_attr("shape", "record")

  let explicit = graph.edge(tail_port, record_head, head_port={
    name: Some("p"),
    compass: None,
  })
  let fallback = graph.edge(tail_plain, record_head, name="fallback")

  let positions : Map[String, @geom.Point] = Map::new()
  positions["tail_port"] = { x: 0.0, y: 0.0 }
  positions["tail_plain"] = { x: 0.0, y: 0.0 }
  positions["record_head"] = { x: 6.0, y: 8.0 }

  let sizes : Map[String, @node_primitives.NodeSize] = Map::new()
  sizes["tail_port"] = @node_primitives.node_size_from_points(10.0, 10.0)
  sizes["tail_plain"] = @node_primitives.node_size_from_points(10.0, 10.0)
  sizes["record_head"] = @node_primitives.node_size_from_points(12.0, 12.0)

  let label_ports_map : Map[String, Map[String, RecordPort]] = Map::new()
  label_ports_map["record_head"] = {
    "p": {
      center: { x: 3.0, y: 4.0 },
      size: @node_primitives.node_size_from_points(2.0, 2.0),
      sides: 0,
    },
  }

  let metrics = build_dot_head_port_metrics(
    [explicit, fallback],
    true,
    positions,
    sizes,
    @layout_prep.RecordOrientation::Horizontal,
    label_ports_map,
  )

  assert_eq(metrics.head_port_counts.get("record_head:p"), Some(1))
  assert_eq(metrics.head_port_min_dist.get("record_head:p"), Some(5.0))
  assert_eq(metrics.head_port_max_dist.get("record_head:p"), Some(5.0))
  assert_eq(metrics.head_port_counts.get("record_head"), Some(1))
  assert_eq(metrics.head_port_min_dist.get("record_head"), Some(10.0))
  assert_eq(metrics.head_port_max_dist.get("record_head"), Some(10.0))
}
