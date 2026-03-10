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
