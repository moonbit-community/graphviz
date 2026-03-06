///|
/// Graphviz parity: head-port metric input keeps edge geometry snapshots and
/// complex-tuning gate grouped before count/min/max aggregation.
pub(all) struct HeadPortMetricBuildInput {
  edges : Array[@cgraph.Edge]
  enable_complex_tuning : Bool
  positions : Map[String, @geom.Point]
  sizes : Map[String, @dot_shared.NodeSize]
}

///|
/// Graphviz parity: head-port metric deps keep record-shape key policy and
/// endpoint-geometry projection explicit for dotsplines-equivalent distance.
pub(all) struct HeadPortMetricBuildDeps {
  is_record_shape : (@cgraph.Node) -> Bool
  node_size_for_missing : (@cgraph.Node) -> @dot_shared.NodeSize
  port_geometry_for : (
    String,
    @cgraph.Port?,
    @geom.Point,
    @dot_shared.NodeSize,
  ) -> RoutePortGeometry
}

///|
/// Graphviz parity: complex head-port tuning keys match dotsplines behavior:
/// explicit port key when present, otherwise record-shape node key.
fn head_metric_key_for_edge(
  edge : @cgraph.Edge,
  is_record_shape : (@cgraph.Node) -> Bool,
) -> String {
  let head_name = edge.head().name()
  let head_port = @dot_shared.port_key(edge.head_port())
  if head_port == "" {
    if (is_record_shape)(edge.head()) { head_name } else { "" }
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
  sizes : Map[String, @dot_shared.NodeSize],
  node_size_for_missing : (@cgraph.Node) -> @dot_shared.NodeSize,
  port_geometry_for : (
    String,
    @cgraph.Port?,
    @geom.Point,
    @dot_shared.NodeSize,
  ) -> RoutePortGeometry,
) -> Double {
  let tail_name = edge.tail().name()
  let head_name = edge.head().name()
  let tail_pos =
    positions.get(tail_name).unwrap_or({
      x: 0.0,
      y: 0.0,
    })
  let head_pos =
    positions.get(head_name).unwrap_or({
      x: 0.0,
      y: 0.0,
    })
  let tail_size =
    sizes.get(tail_name).unwrap_or((node_size_for_missing)(edge.tail()))
  let head_size =
    sizes.get(head_name).unwrap_or((node_size_for_missing)(edge.head()))
  let tail_geometry =
    (port_geometry_for)(
      tail_name,
      edge.tail_port(),
      tail_pos,
      tail_size,
    )
  let head_geometry =
    (port_geometry_for)(
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
pub fn build_head_port_metrics_from_geometry(
  input : HeadPortMetricBuildInput,
  deps : HeadPortMetricBuildDeps,
) -> HeadPortMetrics {
  build_head_port_metrics(
    input.edges,
    input.enable_complex_tuning,
    edge => {
      let key = head_metric_key_for_edge(edge, deps.is_record_shape)
      if key == "" {
        None
      } else {
        let dist =
          head_metric_distance_for_edge(
            edge,
            input.positions,
            input.sizes,
            deps.node_size_for_missing,
            deps.port_geometry_for,
          )
        Some((key, dist))
      }
    },
  )
}
