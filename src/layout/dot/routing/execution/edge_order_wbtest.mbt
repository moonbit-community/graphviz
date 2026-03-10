///|
test "edge route type classifies regular flat and self edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let regular_edge = graph.edge(graph.node("a"), graph.node("b"))
  let flat_edge = build_route_base(regular_edge, is_flat_edge=true)
  let self_edge = graph.edge(graph.node("n"), graph.node("n"))
  let explicit_port = Some(@cgraph.Port::{ name: Some("p"), compass: None })
  let self_noport = build_route_base(
    self_edge,
    orig_tail_name="n",
    orig_head_name="n",
  )
  let self_port = build_route_base(
    self_edge,
    tail_port=explicit_port,
    orig_tail_name="n",
    orig_head_name="n",
  )

  assert_eq(edge_route_type(build_route_base(regular_edge)), ROUTE_EDGE_REGULAR)
  assert_eq(edge_route_type(flat_edge), ROUTE_EDGE_FLAT)
  assert_eq(edge_route_type(self_noport), ROUTE_EDGE_SELF_NOPORT)
  assert_eq(edge_route_type(self_port), ROUTE_EDGE_SELF_PORT)
  assert_eq(edge_route_graph_type(ROUTE_EDGE_REGULAR), ROUTE_GRAPH_MAIN)
  assert_eq(edge_route_graph_type(ROUTE_EDGE_FLAT), ROUTE_GRAPH_AUX)
}

///|
test "edge_port_cmp_info flips flat edge ports when node order is reversed" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let edge = graph.edge(graph.node("a"), graph.node("b"))
  let explicit_tail = Some(@cgraph.Port::{ name: Some("tail"), compass: None })
  let explicit_head = Some(@cgraph.Port::{ name: Some("head"), compass: None })
  let order_index : Map[String, Int] = { "a": 2, "b": 0 }
  let base = build_route_base(
    edge,
    is_flat_edge=true,
    tail_pos=@edge_spline.point(0.0, 0.0),
    head_pos=@edge_spline.point(10.0, 0.0),
    tail_anchor=@edge_spline.point(1.0, 2.0),
    head_anchor=@edge_spline.point(13.0, 4.0),
    tail_port=explicit_tail,
    head_port=explicit_head,
  )

  let info = edge_port_cmp_info(base, ROUTE_EDGE_FLAT, order_index)

  assert_true(info.tail_defined)
  assert_true(info.head_defined)
  assert_point_close(info.tail_pos, @edge_spline.point(3.0, 4.0))
  assert_point_close(info.head_pos, @edge_spline.point(1.0, 2.0))
}

///|
test "sorted_edges_for_routing prioritizes self edges then flat edges then regular edges" {
  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let regular_edge = graph.edge(graph.node("a"), graph.node("b"))
  let flat_edge = graph.edge(graph.node("c"), graph.node("d"))
  let self_edge = graph.edge(graph.node("s"), graph.node("s"))
  let base_cache : Map[Int, EdgeRouteBase] = Map::new()
  base_cache[regular_edge.id()] = build_route_base(
    regular_edge,
    tail_rank=0,
    head_rank=3,
  )
  base_cache[flat_edge.id()] = build_route_base(
    flat_edge,
    is_flat_edge=true,
    tail_rank=0,
    head_rank=0,
  )
  base_cache[self_edge.id()] = build_route_base(
    self_edge,
    orig_tail_name="s",
    orig_head_name="s",
  )

  let ordered = sorted_edges_for_routing(
    [regular_edge, self_edge, flat_edge],
    base_cache,
    Map::new(),
  )

  assert_eq(ordered.map(fn(edge) { edge.id() }), [
    self_edge.id(),
    flat_edge.id(),
    regular_edge.id(),
  ])
}
