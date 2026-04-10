// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0


///|
fn assert_close(
  actual : Double,
  expected : Double,
  eps? : Double = 0.000001,
) -> Unit raise {
  if Double::abs(actual - expected) > eps {
    fail("expected=\{expected} actual=\{actual} eps=\{eps}")
  }
}

///|
test "port order fraction keeps Graphviz cardinal compass quantization" {
  assert_eq(port_order_fraction({ x: 0.0, y: 0.0 }), 0.5)
  assert_close(port_order_fraction({ x: 0.0, y: 1.0 }), 0.0)
  assert_close(port_order_fraction({ x: -1.0, y: 0.0 }), 0.25)
  assert_close(port_order_fraction({ x: 0.0, y: -1.0 }), 0.5)
  assert_close(port_order_fraction({ x: 1.0, y: 0.0 }), 0.75)
}

///|
test "record port sampling uses mapped geometry before compass fallback" {
  let size = @node_primitives.node_size_from_points(8.0, 4.0)
  let info : @record_geometry.RecordPort = {
    center: { x: 10.0, y: 20.0 },
    size,
    sides: 0,
  }
  let offsets : Map[String, Map[String, @record_geometry.RecordPort]] = {
    "n": { "p": info },
  }
  let named_ne : @cgraph.Port = {
    name: Some("p"),
    compass: Some(@cgraph.Compass::NE),
  }
  let named_w : @cgraph.Port = {
    name: Some("p"),
    compass: Some(@cgraph.Compass::W),
  }
  let missing_e : @cgraph.Port = {
    name: Some("missing"),
    compass: Some(@cgraph.Compass::E),
  }

  assert_eq(record_port_point(info, Some(@cgraph.Compass::NE)), {
    x: 14.0,
    y: 22.0,
  })
  assert_eq(
    sample_edge_port_offset("n", Some(named_ne), offsets, _ => 99.0),
    14.0,
  )
  assert_eq(
    sample_edge_port_offset("n", Some(named_w), offsets, _ => 99.0),
    6.0,
  )
  assert_eq(
    sample_edge_port_offset("n", Some(missing_e), offsets, _ => 42.0),
    42.0,
  )
  assert_eq(sample_edge_port_offset("n", None, offsets, _ => 42.0), 0.0)

  let expected_order = port_order_fraction({ x: 14.0, y: 22.0 })
  assert_close(
    sample_edge_port_order("n", Some(named_ne), offsets, _ => {
      x: 100.0,
      y: 0.0,
    }),
    expected_order,
  )
  assert_close(
    sample_edge_port_order("n", Some(missing_e), offsets, _ => {
      x: 1.0,
      y: 0.0,
    }),
    0.75,
  )
  assert_eq(
    sample_edge_port_order("n", None, offsets, _ => { x: 1.0, y: 0.0 }),
    0.0,
  )
}

///|
test "resolve_compass_port_point uses box fallback or shape-clipped point before rankdir offset" {
  let sizes : Map[String, @node_primitives.NodeSize] = {
    "n": @node_primitives.vnode_size_from_widths_with_h(12.0, 18.0, 20.0),
  }
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")

  let box_point = resolve_compass_port_point(
    "n",
    None,
    @cgraph.Compass::NE,
    sizes,
    @rankdir.RankDir::TB,
    _ => false,
    (_node, _size, _compass, _rankdir) => { x: 99.0, y: 99.0 },
    (point, _rankdir) => point,
  )
  assert_eq(box_point, { x: 18.0, y: 10.0 })

  let clipped_point = resolve_compass_port_point(
    "n",
    Some(node),
    @cgraph.Compass::E,
    sizes,
    @rankdir.RankDir::LR,
    _ => true,
    (_node, _size, _compass, _rankdir) => { x: 7.0, y: 3.0 },
    (point, rankdir) => {
      if rankdir == @rankdir.RankDir::LR {
        { x: point.y, y: -point.x }
      } else {
        point
      }
    },
  )
  assert_eq(clipped_point, { x: 3.0, y: -7.0 })
}

///|
test "sample_compass_port_offset keeps unrotated x for record-like nodes" {
  let sizes : Map[String, @node_primitives.NodeSize] = {
    "n": @node_primitives.node_size_from_points(20.0, 10.0),
  }
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("n")

  let rotated = sample_compass_port_offset(
    @cgraph.Compass::E,
    "n",
    sizes,
    @rankdir.RankDir::LR,
    Some(node),
    (_name, _node, _compass, _sizes, _rankdir) => { x: 10.0, y: 4.0 },
    _ => false,
    (point, rankdir) => {
      if rankdir == @rankdir.RankDir::LR {
        { x: point.y, y: -point.x }
      } else {
        point
      }
    },
  )
  assert_eq(rotated, 4.0)

  let unrotated = sample_compass_port_offset(
    @cgraph.Compass::E,
    "n",
    sizes,
    @rankdir.RankDir::LR,
    Some(node),
    (_name, _node, _compass, _sizes, _rankdir) => { x: 10.0, y: 4.0 },
    _ => true,
    (point, rankdir) => {
      if rankdir == @rankdir.RankDir::LR {
        { x: point.y, y: -point.x }
      } else {
        point
      }
    },
  )
  assert_eq(unrotated, 10.0)
}
