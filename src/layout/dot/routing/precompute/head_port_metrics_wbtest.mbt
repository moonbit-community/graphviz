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
test "build_head_port_metrics accumulates count and distance envelope per key" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let c = graph.node("c")
  let e1 = graph.edge(a, b)
  let e2 = graph.edge(c, b)
  let ignored = graph.edge(a, c)

  let metrics = build_head_port_metrics([e1, e2, ignored], true, edge => {
    if edge.id() == e1.id() {
      Some(("b:p", 8.0))
    } else if edge.id() == e2.id() {
      Some(("b:p", 3.0))
    } else {
      None
    }
  })

  assert_eq(metrics.head_port_counts.get("b:p"), Some(2))
  assert_eq(metrics.head_port_min_dist.get("b:p"), Some(3.0))
  assert_eq(metrics.head_port_max_dist.get("b:p"), Some(8.0))
}

///|
test "build_head_port_metrics stays empty when complex tuning is disabled" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let edge = graph.edge(a, b)

  let metrics = build_head_port_metrics([edge], false, _edge => {
    Some(("b:p", 5.0))
  })

  assert_eq(metrics.head_port_counts.length(), 0)
  assert_eq(metrics.head_port_min_dist.length(), 0)
  assert_eq(metrics.head_port_max_dist.length(), 0)
}
