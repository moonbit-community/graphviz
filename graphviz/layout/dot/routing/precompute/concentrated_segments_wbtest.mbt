// Copyright (c) 2026 International Digital Economy Academy
// This program is made available under the terms of the Eclipse Public License 2.0.
// SPDX-License-Identifier: EPL-2.0

///|
test "concentrated port comparison distinguishes undefined from a defined center" {
  let center : @geom.Point? = Some({ x: 0.0, y: 0.0, })
  @test.assert_eq(compare_concentrated_ports(None, center), -1)
  @test.assert_eq(compare_concentrated_ports(center, None), 1)
  @test.assert_eq(compare_concentrated_ports(None, None), 0)
  @test.assert_eq(compare_concentrated_ports(center, center), 0)
  @test.assert_eq(
    compare_concentrated_ports(center, Some({ x: 0.0, y: 1.0, })),
    -1,
  )
}

///|
test "concentrated route sort fixes equal-priority ordering for large inputs" {
  @test.assert_eq(sort_concentrated_route_indices([2, 0, 2, 0, 1]), [
    1, 3, 4, 0, 2,
  ])
  @test.assert_eq(
    sort_concentrated_route_indices([
      3, 1, 4, 1, 5, 9, 2, 6, 5, 3, 5, 8, 9, 7, 9, 3, 2, 3, 8, 4, 6, 2, 6, 4, 3,
      3, 8, 3, 2, 7, 9, 5, 0, 2, 8, 8, 4, 6, 2, 6, 4, 3, 3, 8, 3, 2, 7, 9,
    ]),
    [
      32, 3, 1, 6, 38, 21, 33, 28, 45, 16, 9, 41, 0, 27, 44, 15, 25, 24, 42, 17,
      36, 40, 2, 19, 23, 31, 8, 4, 10, 37, 20, 7, 39, 22, 29, 13, 46, 35, 11, 18,
      26, 34, 43, 47, 14, 12, 5, 30,
    ],
  )
}

///|
test "concentrated entries compare inherited ports before installation identity" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let first : ConcentratedRouteEntry = {
    owner: edge.id(),
    main: edge,
    segment: { tail: "a", head: "_mbt_edge_vn_0_1", vnodes: [], },
    ports: (Some({ x: 0.0, y: 0.0, }), None),
    auxiliary: false,
    edge_type: 1,
  }
  let last = {
    ..first,
    segment: { tail: "_mbt_edge_vn_0_1", head: "b", vnodes: [], },
    ports: (None, Some({ x: 0.0, y: 0.0, })),
  }
  let ranks : Map[String, Int] = { "a": 0, "b": 2 }
  let positions : Map[String, @geom.Point] = {
    "a": { x: 0.0, y: 100.0, },
    "b": { x: 50.0, y: 0.0, },
  }
  @test.assert_eq(
    compare_concentrated_entries(last, first, ranks, positions),
    -1,
  )
  @test.assert_eq(
    compare_concentrated_entries(first, first, ranks, positions),
    0,
  )
  let copy = { ..first, auxiliary: true, }
  @test.assert_eq(
    compare_concentrated_entries(first, copy, ranks, positions),
    -1,
  )
}

///|
test "concentrated sort retains flat and cluster duplicate auxiliary entries" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let cluster = graph.subgraph(name="cluster_a")
  let a = cluster.node("a")
  let b = graph.node("b")
  let c = cluster.node("c")
  let main = graph.edge(a, b)
  let duplicate = graph.edge(a, b)
  let flat = graph.edge(a, c)
  let flat_duplicate = graph.edge(a, c)
  let fast : @setup.ConcentrateFastGraph = {
    copied_from: {},
    edges: [
      {
        tail: "a",
        head: "b",
        weight: 2,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(main),
      },
    ],
    incoming: { "b": [0] },
    outgoing: { "a": [0] },
  }
  let auxiliary = concentrated_auxiliary_routes(
    fast,
    [main, duplicate, flat, flat_duplicate],
    { "a": 0, "b": 1, "c": 0 },
  )
  @test.assert_eq(auxiliary.flat_out["a"].map(edge => edge.id()), [flat.id()])
  @test.assert_eq(auxiliary.other["a"].map(edge => edge.id()), [
    duplicate.id(),
    flat_duplicate.id(),
  ])
  @test.assert_eq(auxiliary.main_edges[duplicate.id()].id(), main.id())
  @test.assert_eq(auxiliary.main_edges[flat_duplicate.id()].id(), flat.id())
}

///|
test "concentrated route ownership keeps incoming and outgoing junction segments" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let h = graph.node("h")
  let ah = graph.edge(a, h)
  let bh = graph.edge(b, h)
  let junction = "_mbt_edge_vn_0_1"
  let fast : @setup.ConcentrateFastGraph = {
    copied_from: {},
    edges: [
      {
        tail: "a",
        head: junction,
        weight: 1,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(ah),
      },
      {
        tail: "b",
        head: junction,
        weight: 1,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(bh),
      },
      {
        tail: junction,
        head: "h",
        weight: 2,
        tail_port: None,
        head_port: None,
        to_virtual: None,
        original: Some(ah),
      },
    ],
    incoming: Map([(junction, [0, 1]), ("h", [2])]),
    outgoing: Map([("a", [0]), ("b", [1]), (junction, [2])]),
  }
  let segments = collect_concentrated_segments(
    fast,
    { 0: ["a", "b"], 1: [junction], 2: ["h"] },
    { "a": 0, "b": 0, "h": 2 },
    {
      "a": { x: 0.0, y: 100.0, },
      "b": { x: 100.0, y: 100.0, },
      "h": { x: 50.0, y: 0.0, },
    },
  )
  @test.assert_eq(segments[ah.id()].length(), 2)
  @test.assert_eq(segments[bh.id()].length(), 1)
  let endpoints : Map[String, String] = Map([])
  for segment in segments[ah.id()] {
    endpoints[segment.tail] = segment.head
    @test.assert_eq(segment.vnodes.length(), 0)
  }
  @test.assert_eq(endpoints, Map([("a", junction), (junction, "h")]))
  @test.assert_eq(segments[bh.id()][0].tail, "b")
  @test.assert_eq(segments[bh.id()][0].head, junction)
}
