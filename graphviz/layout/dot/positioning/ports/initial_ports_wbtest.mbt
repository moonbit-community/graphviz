// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "initial named compass ports rotate the displacement in LR" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let node = graph.node("rotated")
  let offsets : Map[String, Map[String, RecordPort]] = {
    "rotated": {
      "p": {
        center: { x: 5.0, y: 7.0, },
        size: @node_primitives.node_size_from_points(20.0, 10.0),
        sides: 15,
      },
    },
  }
  let point = initial_port_point(
    node,
    Some({ name: Some("p"), compass: Some(@cgraph.Compass::N), }),
    offsets,
    Map([]),
    @rankdir.RankDir::LR,
  )
  assert_eq(point, Some({ x: 15.0, y: 7.0, }))
  assert_eq(
    edge_port_offset(
      "rotated",
      Some({ name: Some("p"), compass: Some(@cgraph.Compass::N), }),
      offsets,
      Map([]),
      @rankdir.RankDir::LR,
      { "rotated": node },
    ),
    15.0,
  )
}

///|
test "initial ports compare coordinates rather than matching field names" {
  @label_layout.reset_label_caches()
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  a.set_attr("shape", "record")
  b.set_attr("shape", "record")
  a.set_attr("label", "<p>short|<q>x")
  b.set_attr("label", "<p>a much wider field|<q>x")
  let p : @cgraph.Port = { name: Some("p"), compass: None, }
  let q : @cgraph.Port = { name: Some("q"), compass: None, }
  let forward = graph.edge(a, b, tail_port=p, head_port=q)
  let backward = graph.edge(b, a, tail_port=p, head_port=q)
  let ports_equal = build_initial_edge_port_comparator([a, b], Map([]))
  assert_false(ports_equal(backward, forward))
}

///|
test "initial ports with different field names can have equal coordinates" {
  @label_layout.reset_label_caches()
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  a.set_attr("shape", "record")
  b.set_attr("shape", "record")
  a.set_attr("label", "<p>same|<q>value")
  b.set_attr("label", "<x>same|<y>value")
  let first = graph.edge(a, a, tail_port={ name: Some("p"), compass: None, }, head_port={
    name: Some("q"),
    compass: None,
  })
  let second = graph.edge(b, b, tail_port={ name: Some("x"), compass: None, }, head_port={
    name: Some("y"),
    compass: None,
  })
  let ports_equal = build_initial_edge_port_comparator([a, b], Map([]))
  assert_true(ports_equal(first, second))
}

///|
test "initial ports preserve head definedness and asymmetric tail comparison" {
  @label_layout.reset_label_caches()
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  a.set_attr("shape", "record")
  b.set_attr("shape", "record")
  a.set_attr("label", "<p>left|right")
  b.set_attr("label", "<center>center")
  let plain = graph.edge(a, b)
  let defined_head = graph.edge(a, b, head_port={
    name: Some("center"),
    compass: None,
  })
  let defined_tail = graph.edge(a, b, tail_port={
    name: Some("p"),
    compass: None,
  })
  let ports_equal = build_initial_edge_port_comparator([a, b], Map([]))
  assert_false(ports_equal(plain, defined_head))
  assert_true(ports_equal(plain, defined_tail))
  assert_false(ports_equal(defined_tail, plain))
}
