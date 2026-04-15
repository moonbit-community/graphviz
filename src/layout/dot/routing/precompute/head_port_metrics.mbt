// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
pub(all) struct RoutePortGeometry {
  center : @geom.Point
  size : @node_primitives.NodeSize
}

///|
pub(all) struct HeadPortMetrics {
  head_port_counts : Map[String, Int]
  head_port_min_dist : Map[String, Double]
  head_port_max_dist : Map[String, Double]
}

///|
/// Graphviz parity: head-port metric aggregation mirrors dotsplines
/// count/min/max accumulation for complex tuning.
pub fn build_head_port_metrics(
  edges : Array[@cgraph.Edge],
  enable_complex_tuning : Bool,
  edge_metric_sample : (@cgraph.Edge) -> (String, Double)?,
) -> HeadPortMetrics {
  let head_port_counts : Map[String, Int] = Map::new()
  let head_port_min_dist : Map[String, Double] = Map::new()
  let head_port_max_dist : Map[String, Double] = Map::new()
  if enable_complex_tuning {
    for edge in edges {
      match edge_metric_sample(edge) {
        Some((key, dist)) => {
          let current = head_port_counts.get(key).unwrap_or_default()
          head_port_counts[key] = current + 1
          let mut min_dist = head_port_min_dist.get(key).unwrap_or(dist)
          let mut max_dist = head_port_max_dist.get(key).unwrap_or(dist)
          if dist < min_dist {
            min_dist = dist
          }
          if dist > max_dist {
            max_dist = dist
          }
          head_port_min_dist[key] = min_dist
          head_port_max_dist[key] = max_dist
        }
        None => ()
      }
    }
  }
  { head_port_counts, head_port_min_dist, head_port_max_dist }
}

///|
/// Graphviz parity: complex head-port tuning keys match dotsplines behavior:
/// explicit port key when present, otherwise record-shape node key.
fn head_metric_key_for_edge(
  edge : @cgraph.Edge,
  is_record_shape : (@cgraph.Node) -> Bool,
) -> String {
  let head_name = edge.head().name()
  let head_port = @edge_identity.port_key(edge.head_port())
  if head_port == "" {
    if is_record_shape(edge.head()) {
      head_name
    } else {
      ""
    }
  } else {
    "\{head_name}:\{head_port}"
  }
}

///|
/// Graphviz parity: complex tuning distance uses endpoint port centers in
/// current routing coordinates.
fn head_metric_distance_for_edge(
  edge : @cgraph.Edge,
  positions : Map[String, @geom.Point],
  sizes : Map[String, @node_primitives.NodeSize],
  node_size_for_missing : (@cgraph.Node) -> @node_primitives.NodeSize,
  port_geometry_for : (
    String,
    @cgraph.Port?,
    @geom.Point,
    @node_primitives.NodeSize,
  ) -> RoutePortGeometry,
) -> Double {
  let tail_name = edge.tail().name()
  let head_name = edge.head().name()
  let tail_pos = positions.get(tail_name).unwrap_or({ x: 0.0, y: 0.0 })
  let head_pos = positions.get(head_name).unwrap_or({ x: 0.0, y: 0.0 })
  let tail_size = sizes
    .get(tail_name)
    .unwrap_or(node_size_for_missing(edge.tail()))
  let head_size = sizes
    .get(head_name)
    .unwrap_or(node_size_for_missing(edge.head()))
  let tail_geometry = port_geometry_for(
    tail_name,
    edge.tail_port(),
    tail_pos,
    tail_size,
  )
  let head_geometry = port_geometry_for(
    head_name,
    edge.head_port(),
    head_pos,
    head_size,
  )
  let dx = head_geometry.center.x - tail_geometry.center.x
  let dy = head_geometry.center.y - tail_geometry.center.y
  Double::sqrt(dx * dx + dy * dy)
}

///|
/// Graphviz parity: head-port metric aggregation mirrors dotsplines
/// count/min/max accumulation for complex tuning.
fn build_head_port_metrics_from_geometry(
  edges : Array[@cgraph.Edge],
  enable_complex_tuning : Bool,
  positions : Map[String, @geom.Point],
  sizes : Map[String, @node_primitives.NodeSize],
  is_record_shape : (@cgraph.Node) -> Bool,
  node_size_for_missing : (@cgraph.Node) -> @node_primitives.NodeSize,
  port_geometry_for : (
    String,
    @cgraph.Port?,
    @geom.Point,
    @node_primitives.NodeSize,
  ) -> RoutePortGeometry,
) -> HeadPortMetrics {
  build_head_port_metrics(edges, enable_complex_tuning, edge => {
    let key = head_metric_key_for_edge(edge, is_record_shape)
    if key == "" {
      None
    } else {
      let dist = head_metric_distance_for_edge(
        edge, positions, sizes, node_size_for_missing, port_geometry_for,
      )
      Some((key, dist))
    }
  })
}

///|
/// Dot-specific head-port metric assembly for routing precompute.
type RecordOrientation = @layout_prep.RecordOrientation

///|
type RecordPort = @record_geometry.RecordPort

///|
/// Graphviz parity: dot head-port metrics keep record/html port geometry and
/// record-shape distance sampling aligned with Stage E complex-tuning rules.
/// Do not change behavior without updating fixtures/tests.
pub fn build_dot_head_port_metrics(
  edges : Array[@cgraph.Edge],
  enable_complex_tuning : Bool,
  positions : Map[String, @geom.Point],
  sizes : Map[String, @node_primitives.NodeSize],
  record_orientation : RecordOrientation,
  label_ports_map : Map[String, Map[String, RecordPort]],
) -> HeadPortMetrics {
  build_head_port_metrics_from_geometry(
    edges,
    enable_complex_tuning,
    positions,
    sizes,
    @record_geometry.is_record_shape,
    node => @node_geometry.node_size(node, record_orientation),
    (node_name, port, node_pos, node_size) => {
      let geometry = @port_geometry.port_geometry(
        node_name, port, label_ports_map, node_pos, node_size,
      )
      { center: geometry.center, size: geometry.size }
    },
  )
}
