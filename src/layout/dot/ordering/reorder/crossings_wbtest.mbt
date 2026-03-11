///|
test "project_rank_pair_crossings groups crossing and local port data once" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["a", "b"]
  groups[1] = ["x", "y"]

  let ranks : Map[String, Int] = Map::new()
  ranks["a"] = 0
  ranks["b"] = 0
  ranks["x"] = 1
  ranks["y"] = 1
  ranks["ext"] = 1

  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let a = graph.node("a")
  let b = graph.node("b")
  let x = graph.node("x")
  let y = graph.node("y")
  let ext = graph.node("ext")
  let edges = [
    graph.edge(a, y),
    graph.edge(a, x),
    graph.edge(a, ext),
    graph.edge(b, x),
  ]

  let inputs = build_port_aware_crossing_inputs(
    groups,
    edges,
    ["a", "a", "a", "b"],
    ["y", "x", "ext", "x"],
    ranks~,
  )
  let projected = project_rank_pair_crossings(
    ["a", "b"],
    ["x", "y"],
    1,
    @rank_groups.build_order_index(groups),
    { "ext": 3 },
    inputs,
    ["y", "x", "ext", "x"],
    [2.0, 1.0, 5.0, 0.0],
    [0.0, 0.0, 0.0, 4.0],
  )

  assert_eq(
    projected.crossing_slots_by_top,
    [[(1, 1), (0, 1), (3, 1)], [(0, 1)]],
  )
  assert_eq(
    projected.local_out_by_top,
    [[(1, 2.0, 1), (0, 1.0, 1)], [(0, 0.0, 1)]],
  )
  assert_eq(
    projected.local_in_by_bottom,
    [[(0, 0.0, 1), (1, 4.0, 1)], [(0, 0.0, 1)]],
  )
  assert_eq(projected.max_slot, 3)
}

///|
test "count_crossings_port_aware includes local port crossings for same node fanout" {
  let groups : Map[Int, Array[String]] = Map::new()
  groups[0] = ["p"]
  groups[1] = ["x", "y"]

  let ranks : Map[String, Int] = Map::new()
  ranks["p"] = 0
  ranks["x"] = 1
  ranks["y"] = 1

  let graph = @cgraph.Graph::new(@cgraph.GraphKind::Directed, strict=false)
  let p = graph.node("p")
  let x = graph.node("x")
  let y = graph.node("y")
  let edges = [graph.edge(p, x), graph.edge(p, y)]

  let crossings = count_crossings_port_aware(
    groups,
    ranks,
    edges,
    ["p", "p"],
    ["x", "y"],
    edge_tail_port_x=[2.0, 1.0],
    edge_head_port_x=[],
  )

  assert_eq(crossings, 1)
}
